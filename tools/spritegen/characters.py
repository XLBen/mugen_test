"""原创角色定义：体型 + 造型 + 两套配色（第二套用于同角色镜像对战）。"""

FEMALE = dict(
	thigh=27, shin=26, torso=33, uarm=17, farm=16, foot=6,
	head_rx=6.5, head_ry=7.5,
	thigh_w=8, knee_w=5.5, ankle_w=4.5,
	uarm_w=5, elbow_w=4.2, wrist_w=3.6, hand_r=2.3,
	hip_w=6.5, waist_w=4.8, chest_w=6.5, shoulder_w=12,
)

MALE = dict(
	thigh=29, shin=28, torso=37, uarm=19, farm=18, foot=7,
	head_rx=6.5, head_ry=7.5,
	thigh_w=9, knee_w=6.5, ankle_w=5.5,
	uarm_w=6.5, elbow_w=5.5, wrist_w=4.5, hand_r=2.8,
	hip_w=7, waist_w=6.5, chest_w=8, shoulder_w=16,
)

CHARACTERS = {
	# 白色长发、红白和风上衣 + 短裙、短刀
	"kagura": dict(
		name="Kagura",
		body=FEMALE,
		hair="long",
		skirt="short",
		weapon="knife",
		eyes=(210, 40, 50),
		stance=dict(uarm_f=22, farm_f=78, knife=75),
		# 短刀近身：拳类攻击手臂弯曲，用刀弧而不是伸直手臂（距离比 Mio 短）
		pose_overrides={
			"5mp": dict(uarm_f=70, farm_f=110, knife=40),
			"5hp": dict(uarm_f=60, farm_f=118, torso=14, knife=30),
			"2mp": dict(uarm_f=70, farm_f=108, knife=40),
		},
		palettes=[
			dict(skin=(252, 224, 206), hair=(232, 232, 242), top=(238, 236, 240), sleeve=(238, 236, 240),
				collar=(200, 40, 52), sash=(200, 40, 52), skirt=(178, 32, 48),
				legs=(42, 40, 52), thigh_skin=True, shoes=(70, 40, 36)),
			dict(skin=(252, 224, 206), hair=(182, 172, 218), top=(52, 58, 98), sleeve=(52, 58, 98),
				collar=(232, 232, 238), sash=(232, 232, 238), skirt=(228, 228, 238),
				legs=(238, 238, 244), thigh_skin=True, shoes=(40, 40, 52)),
		],
	),
	# 高个男性、短刺发、黑色长大衣 + 长围巾
	"volk": dict(
		name="Volk",
		body=MALE,
		hair="spiky",
		coat=True,
		scarf=True,
		eyes=(214, 176, 60),
		stance=dict(torso=10, uarm_f=40, farm_f=128, uarm_b=25, farm_b=115),
		# 个子高：上勾拳要更靠前、更低，才能打到站着的对手
		pose_overrides={"2hp": dict(uarm_f=112, farm_f=140, torso=16)},
		palettes=[
			dict(skin=(236, 206, 186), hair=(44, 48, 66), top=(54, 54, 64), sleeve=(54, 54, 64), coat=(54, 54, 64),
				collar=(196, 196, 206), scarf=(176, 30, 42), legs=(38, 38, 48), shoes=(30, 26, 26),
				gloves=(30, 30, 36)),
			dict(skin=(236, 206, 186), hair=(214, 190, 140), top=(104, 52, 44), sleeve=(104, 52, 44),
				coat=(104, 52, 44), collar=(40, 40, 48), scarf=(226, 226, 232), legs=(52, 44, 40),
				shoes=(40, 30, 26), gloves=(60, 40, 32)),
		],
	),
	# 黑发双马尾、黑白长裙、宽袖
	"mio": dict(
		name="Mio",
		body=dict(FEMALE, sleeve_flare=2.5),
		hair="twintails",
		skirt="long",
		weapon="ribbon",
		eyes=(90, 140, 220),
		stance=dict(torso=4, uarm_f=35, farm_f=110),
		palettes=[
			dict(skin=(252, 228, 214), hair=(34, 32, 44), top=(36, 32, 46), sleeve=(36, 32, 46),
				cuff=(238, 238, 244), collar=(238, 238, 244), skirt=(36, 32, 46), apron=(238, 238, 244),
				legs=(236, 236, 242), shoes=(30, 28, 36), ribbon=(200, 36, 60)),
			dict(skin=(252, 228, 214), hair=(236, 160, 186), top=(40, 52, 100), sleeve=(40, 52, 100),
				cuff=(238, 238, 244), collar=(238, 238, 244), skirt=(40, 52, 100), apron=(238, 238, 244),
				legs=(236, 236, 242), shoes=(30, 28, 36), ribbon=(240, 200, 80)),
		],
	),
}
