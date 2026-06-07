--!strict
-- Chapters (BLOX PROTECTOR). A chapter = a finite, story-framed run of waves on its
-- own map, with dialogue beats, a boss, and a title/end card.

export type EndCard = { title: string, teaser: string, thanks: string }

export type Chapter = {
	id: number,
	title: string,
	framing: string,
	waves: number, -- survive this many waves to complete the chapter (then VICTORY)
	introKey: string, -- dialogue key played before wave 1
	bossIntroKey: string, -- dialogue key when the boss spawns (final wave)
	endKey: string, -- dialogue key played on completion (final chapter only)
	beats: { [number]: string }, -- waveNumber -> non-blocking toast text
	boss: string, -- enemy id spawned on the final wave
	endCard: EndCard,
}

local Chapters: { Chapter } = {
	{
		id = 1,
		title = "Chapter 1: The First Upload",
		framing = "Reclaim the Crossroads from a digital infestation of shiny, PBR-textured invaders.",
		waves = 8,
		introKey = "intro",
		bossIntroKey = "boss_intro",
		endKey = "chapterEnd",
		beats = {
			[3] = "Heads up — the Glitch is multi-threading! They're coming in pairs now!",
			[5] = "That's a LOT of syntax errors incoming... keep building or we crash!",
		},
		boss = "Boss",
		endCard = {
			title = "CHAPTER 1 COMPLETE — Crossroads Restored!",
			teaser = "Next time... Chapter 2: The Haunted Mansion of 1x1x1x1.",
			thanks = "Thanks for testing the '08 Alpha. Your save is in the cloud.",
		},
	},
	{
		id = 2,
		title = "Chapter 2: The Deep Scan",
		framing = "The corruption runs deeper here — a new layout, and something massive compiling at its core.",
		waves = 8,
		introKey = "intro",
		bossIntroKey = "boss2_intro",
		endKey = "chapterEnd",
		beats = {
			[3] = "They're adapting to your build order — mix it up!",
			[5] = "The Mainframe is spinning up. Hold the line!",
		},
		boss = "Boss2",
		endCard = {
			title = "DEMO COMPLETE — You held the line!",
			teaser = "The full Smoothing still looms... but that's a story for another build.",
			thanks = "Thanks for playing the BLOX PROTECTOR demo!",
		},
	},
}

return Chapters
