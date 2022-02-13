return {
PlaceObj('ModItemCode', {
	'FileName', "Code/Script.lua",
}),
PlaceObj('ModItemOptionToggle', {
	'name', "AutoBalance",
	'DisplayName', "Automatically Balance Depots",
	'Help', "Balance depots instead of leaving all resouces",
	'DefaultValue', true,
}),
PlaceObj('ModItemOptionToggle', {
	'name', "OffloadToMechs",
	'DisplayName', "Offload Extra Resources to Storage",
	'Help', "Move extra resources to mechanical storage instead of depots",
	'DefaultValue', true,
}),
PlaceObj('ModItemOptionNumber', {
	'name', "Delay",
	'comment', "delay between re-calculation",
	'DisplayName', "Update Delay",
	'Help', "How many hours to wait between re-calculating depot balance (default: 2)",
	'DefaultValue', 2,
	'MinValue', 1,
	'MaxValue', 25,
}),
PlaceObj('ModItemOptionToggle', {
	'name', "LowLoadOnly",
	'DisplayName', "Only Move Resources on Low Drone Load",
	'Help', "Don't move resources when drones are busy",
}),
PlaceObj('ModItemOptionToggle', {
	'name', "ShowWarnings",
	'DisplayName', "Show low resource warnings",
	'Help', "Show warnings when there are not enough resources to fill depots",
	'DefaultValue', true,
}),
}
