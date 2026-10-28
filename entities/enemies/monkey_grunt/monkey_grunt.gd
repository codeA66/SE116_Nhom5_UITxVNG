class_name MonkeyGrunt
extends WildEnemy
## Hai đòn dùng cùng khoảng hồi chung; chọn ngẫu nhiên trong các đòn sẵn sàng.
func choose_skill() -> EnemySkillData:
	return choose_random_skill()
