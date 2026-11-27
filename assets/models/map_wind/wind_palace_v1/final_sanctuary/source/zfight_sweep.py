"""Quét mặt song song chồng nhau trên glTF đã xuất, có tính transform của node."""
from pathlib import Path
import ast
from itertools import product
import json
import math
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
PROJECT=HERE.parents[5]
GAP=0.02
AREA=0.002
CELL=2.0
NORMAL_NEIGHBORS=tuple(product((-1,0,1),repeat=3))


def helpers() -> dict:
    path=PROJECT/"assets/models/map_temple/source/zfight_sweep.py"
    tree=ast.parse(path.read_text(encoding="utf-8"))
    tree.body=[node for node in tree.body if not (isinstance(node,ast.Expr) and isinstance(node.value,ast.Call) and isinstance(node.value.func,ast.Name) and node.value.func.id=="main")]
    scope={"__file__":str(path),"__name__":"sanctuary_sweep_helpers"}
    exec(compile(tree,str(path),"exec"),scope)
    return scope


def transform(node: dict) -> np.ndarray:
    if "matrix" in node:
        return np.array(node["matrix"],dtype=float).reshape(4,4).T
    q=node.get("rotation",[0,0,0,1])
    x,y,z,w=q
    rotation=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
        [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
        [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    result=np.eye(4)
    result[:3,:3]=rotation@np.diag(node.get("scale",[1,1,1]))
    result[:3,3]=node.get("translation",[0,0,0])
    return result


def load_faces() -> tuple:
    read=helpers()["read_accessor"]
    triangles=[]
    labels=[]
    for path in sorted((ROOT/"geometry").glob("*/*.gltf")):
        doc=json.loads(path.read_text(encoding="utf-8"))
        buffers={}
        def visit(index: int, parent: np.ndarray) -> None:
            node=doc["nodes"][index]
            matrix=parent@transform(node)
            if "mesh" in node and not node.get("name","").endswith("-colonly"):
                for prim in doc["meshes"][node["mesh"]]["primitives"]:
                    points=read(doc,str(path.parent),buffers,prim["attributes"]["POSITION"]).astype(float)
                    points=points@matrix[:3,:3].T+matrix[:3,3]
                    ids=read(doc,str(path.parent),buffers,prim["indices"]).reshape(-1,3)
                    faces=points[ids]
                    triangles.extend(faces)
                    labels.extend([path.stem+"/"+node.get("name",str(index))]*len(faces))
            for child in node.get("children",[]):
                visit(child,matrix)
        for root in doc["scenes"][doc.get("scene",0)]["nodes"]:
            visit(root,np.eye(4))
    return np.array(triangles),labels


def clip(poly: list, triangle: np.ndarray) -> list:
    cross=lambda a,b: a[0]*b[1]-a[1]*b[0]
    sign=1 if cross(triangle[1]-triangle[0],triangle[2]-triangle[0])>0 else -1
    for i in range(3):
        if not poly:
            return []
        start=triangle[i]
        edge=triangle[(i+1)%3]-start
        old=poly[-1]
        old_side=sign*cross(edge,old-start)
        result=[]
        for point in poly:
            side=sign*cross(edge,point-start)
            if (side>=0)!=(old_side>=0):
                result.append(old+(point-old)*(old_side/(old_side-side)))
            if side>=0:
                result.append(point)
            old,old_side=point,side
        poly=result
    return poly


def area(poly: list) -> float:
    if len(poly)<3:
        return 0.0
    p=np.array(poly)
    return abs(np.sum(p[:,0]*np.roll(p[:,1],-1)-p[:,1]*np.roll(p[:,0],-1)))*0.5


def sweep() -> int:
    triangles,labels=load_faces()
    print("SWEEP loaded triangles=",len(triangles),flush=True)
    raw=np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])
    lengths=np.linalg.norm(raw,axis=1)
    normals=raw/np.maximum(lengths[:,None],1e-12)
    lo=triangles.min(axis=1)-GAP
    hi=triangles.max(axis=1)+GAP
    cells={}
    bad={}
    for i,triangle in enumerate(triangles):
        if lengths[i]<1e-7:
            continue
        lower=np.floor(lo[i]/CELL).astype(int)
        upper=np.floor(hi[i]/CELL).astype(int)
        candidates=set()
        keys=[]
        normal_key=np.floor(normals[i]*50).astype(int)
        for x in range(lower[0],upper[0]+1):
            for y in range(lower[1],upper[1]+1):
                for z in range(lower[2],upper[2]+1):
                    key=(x,y,z,*normal_key)
                    keys.append(key)
                    for nx,ny,nz in NORMAL_NEIGHBORS:
                        candidates.update(cells.get((x,y,z,normal_key[0]+nx,normal_key[1]+ny,normal_key[2]+nz),()))
        if candidates:
            ids=np.fromiter(candidates,dtype=int)
            near=(np.einsum("ij,j->i",normals[ids],normals[i])>0.99998)
            near&=(lo[ids]<=hi[i]).all(axis=1)&(hi[ids]>=lo[i]).all(axis=1)
            gaps=np.einsum("ikj,j->ik",triangles[ids]-triangle[0],normals[i])
            near&=(np.abs(gaps).max(axis=1)<GAP)
            axis=int(np.argmax(np.abs(normals[i])))
            axes=[a for a in range(3) if a!=axis]
            for j in ids[near]:
                # Hai mặt có cạnh chung chỉ tiếp giáp khi được raster hóa.
                same_vertices=(np.linalg.norm(triangle[:,None,:]-triangles[j][None,:,:],axis=2)<0.00001).any(axis=1)
                if same_vertices.sum() == 2:
                    continue
                pair=tuple(sorted((labels[i],labels[j])))
                if pair in bad:
                    continue
                overlap=clip(list(triangle[:,axes]),triangles[j][:,axes])
                if area(overlap)>AREA:
                    bad[pair]="%s <> %s tại %s"%(*pair,np.round(triangle.mean(axis=0),3))
        for key in keys:
            cells.setdefault(key,[]).append(i)
    print("SANCTUARY ZFIGHT triangles=%d pairs=%d"%(len(triangles),len(bad)),flush=True)
    for value in bad.values():
        print(value,flush=True)
    return len(bad)


if __name__=="__main__":
    sys.exit(1 if sweep() else 0)
