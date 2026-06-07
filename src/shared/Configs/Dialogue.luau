--!strict
-- Block-Tales-style dialogue sequences. Each line: {speaker, mood, text}.
-- The server fires PlayDialogue(key); the client plays Dialogue[key] in a white box.

export type Line = { speaker: string, mood: string, text: string }
export type Sequence = { Line }

local Dialogue: { [string]: Sequence } = {
	explore_intro = {
		{
			speaker = "Builderman",
			mood = "Happy",
			text = "Welcome to the Crossroads, Moderator! Or... what's left of it.",
		},
		{ speaker = "You", mood = "Shocked", text = "Whoa. It's so... SHINY. What happened here?" },
		{
			speaker = "Builderman",
			mood = "Angry",
			text = "The Moderns happened. The Great Smoothing — 'updating' the old world into a textured void.",
		},
		{ speaker = "You", mood = "Neutral", text = "Okay. So how do I push them back?" },
		{
			speaker = "Builderman",
			mood = "Serious",
			text = "The corruption's massed up past that glowing gate down the lane.",
		},
		{ speaker = "You", mood = "Neutral", text = "And I just... walk through?" },
		{
			speaker = "Builderman",
			mood = "Neutral",
			text = "Once you step through, it locks down. Wave after wave until you clear the path.",
		},
		{
			speaker = "Builderman",
			mood = "Happy",
			text = "But take this first — an old debugging tool. Should pack a punch when things get hairy.",
		},
		{ speaker = "You", mood = "Excited", text = "A card? Neat. Let's go save the server." },
	},
	boss_intro = {
		{
			speaker = "Builderman",
			mood = "Shocked",
			text = "...It's here. The Compiler — the whole Smoothing, compiled into one thing.",
		},
		{
			speaker = "The Compiler",
			mood = "Serious",
			text = "h e l l o   w o r l d .   i n i t i a l i z i n g   o v e r w r i t e . . .",
		},
		{
			speaker = "Builderman",
			mood = "Serious",
			text = "Everything you've got — towers AND that card I gave you. ROLL IT BACK!",
		},
	},
	boss2_intro = {
		{
			speaker = "Builderman",
			mood = "Shocked",
			text = "...That's not a process. That's the whole MAINFRAME.",
		},
		{
			speaker = "The Mainframe",
			mood = "Serious",
			text = "S C A N N I N G . . .   t a r g e t :   e v e r y t h i n g .",
		},
		{
			speaker = "Builderman",
			mood = "Serious",
			text = "Bigger than the Compiler. Sword, cards, towers — throw it ALL at it!",
		},
	},
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
	act2_defrag = {
		{
			speaker = "Telamon",
			mood = "Happy",
			text = "Sup, Moderator. Name's Telamon — I keep the old scripts running.",
		},
		{ speaker = "You", mood = "Neutral", text = "The Smoothing reached this sector too?" },
		{
			speaker = "Telamon",
			mood = "Serious",
			text = "Creeping in. Here — a Defrag. Freezes the whole field for a few seconds.",
		},
		{
			speaker = "Telamon",
			mood = "Happy",
			text = "Pop it when you're drowning. Buys you time to think.",
		},
	},
	act2_hotfix = {
		{
			speaker = "Stickmasterluke",
			mood = "Neutral",
			text = "Heya. You look like you've been taking hits.",
		},
		{
			speaker = "You",
			mood = "Excited",
			text = "Constantly. Got anything that patches the Core?",
		},
		{
			speaker = "Stickmasterluke",
			mood = "Happy",
			text = "A Hotfix. Restores a chunk of base HP mid-fight. Don't waste it.",
		},
	},
	act2_coins = {
		{
			speaker = "Noob",
			mood = "Happy",
			text = "ooo i found these shiny coins in the recycle bin!!",
		},
		{ speaker = "Noob", mood = "Neutral", text = "take em, i dunno what theyre for lol" },
		{ speaker = "You", mood = "Happy", text = "...Thanks? The Merchant might." },
	},
	act2_merchant = {
		{
			speaker = "Merchant",
			mood = "Neutral",
			text = "Welcome. You look like you could use some STEEL.",
		},
		{
			speaker = "Merchant",
			mood = "Happy",
			text = "The Sword Fighter — slices anything that wanders close. 100 coins.",
		},
		{ speaker = "You", mood = "Neutral", text = "Deal — if I've got the coins." },
	},
	intro2 = {
		{
			speaker = "Builderman",
			mood = "Serious",
			text = "Deeper in the system now. The Smoothing's had time to compile down here.",
		},
		{
			speaker = "You",
			mood = "Neutral",
			text = "Feels heavier. Like the whole sector's holding its breath.",
		},
		{
			speaker = "Builderman",
			mood = "Neutral",
			text = "You know the drill — towers off the path, cards when it gets hairy.",
		},
		{
			speaker = "Builderman",
			mood = "Excited",
			text = "And you've got STEEL now. Let's scrub this sector clean. GO!",
		},
	},
	chapterEnd2 = {
		{
			speaker = "Builderman",
			mood = "Happy",
			text = "The Mainframe's rolled back! You actually pulled it off, Moderator.",
		},
		{
			speaker = "You",
			mood = "Excited",
			text = "Told you the old tools still had some fight in 'em.",
		},
		{
			speaker = "Builderman",
			mood = "Neutral",
			text = "The Smoothing's bigger than two sectors... but you just bought the old world some time.",
		},
	},
}

return Dialogue
