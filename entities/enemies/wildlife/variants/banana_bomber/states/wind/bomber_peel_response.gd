extends BananaPeelResponse
## Vỏ chuối không được cướp điều khiển giữa quãng bị E hất, các lúc khác vẫn trượt bình thường.
func step_on_peel() -> bool:
	return (get_parent() as BananaBomber).is_wind_launched
