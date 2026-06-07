--!strict
-- Block-Tales-style dialogue sequences. Each line: {speaker, mood, text}.
-- The server fires PlayDialogue(key); the client plays Dialogue[key] in a white box.

export type Line = { speaker: string, mood: string, text: string }
export type Sequence = { Line }

local Dialogue: { [string]: Sequence } = {
	intro = {
		{
			speaker = "Builderman",
			mood = "Neutral",
			text = "Hey! You! The one clicking the mouse!",
		},
		{
			speaker = "Builderman",
			mood = "Angry",
			text = "Look at what they're doing to the Database! It's... it's... SHINY.",
		},
		{
			speaker = "Builderman",
			mood = "Shocked",
			text = "The 'Great Smoothing' has begun. They're trying to UPDATE us!",
		},
		{
			speaker = "Builderman",
			mood = "Neutral",
			text = "If they reach the Database Core, we all get Deleted.",
		},
		{
			speaker = "Builderman",
			mood = "Happy",
			text = "Good news — I found some old building tools in the Recycle Bin.",
		},
		{
			speaker = "Builderman",
			mood = "Neutral",
			text = "Pick a tower from the bar (or press 1-3) and plant it off the path.",
		},
		{
			speaker = "Builderman",
			mood = "Serious",
			text = "Don't let those high-poly freaks touch our source code!",
		},
		{
			speaker = "Builderman",
			mood = "Excited",
			text = "Ready? I'm hitting 'Run Script' now. Don't let me down!",
		},
	},
	wave3 = {
		{
			speaker = "Builderman",
			mood = "Shocked",
			text = "Heads up — the Glitch is multi-threading! They're coming in pairs now!",
		},
	},
	wave5 = {
		{
			speaker = "Builderman",
			mood = "Serious",
			text = "That's a LOT of syntax errors incoming... keep building or we crash!",
		},
	},
	chapterEnd = {
		{
			speaker = "Builderman",
			mood = "Happy",
			text = "We did it! The Crossroads is rendering in beautiful blocky glory again!",
		},
		{
			speaker = "Builderman",
			mood = "Neutral",
			text = "But the Smoothing runs deep. This was only the first upload...",
		},
	},
}

return Dialogue
