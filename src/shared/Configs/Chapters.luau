--!strict
-- Chapters (BLOX PROTECTOR). A chapter = a finite, story-framed run of waves with
-- dialogue beats and a title/end card. Chapter 1 is the playable demo slice.

export type EndCard = { title: string, teaser: string, thanks: string }

export type Chapter = {
	id: number,
	title: string,
	framing: string,
	waves: number, -- survive this many waves to complete the chapter (then VICTORY)
	introKey: string, -- dialogue key played before wave 1
	endKey: string, -- dialogue key played on completion
	beats: { [number]: string }, -- waveNumber -> dialogue key (fired at that wave's start)
	endCard: EndCard,
}

local Chapters: { Chapter } = {
	{
		id = 1,
		title = "Chapter 1: The First Upload",
		framing = "Reclaim the Crossroads from a digital infestation of shiny, PBR-textured invaders.",
		waves = 8,
		introKey = "intro",
		endKey = "chapterEnd",
		beats = { [3] = "wave3", [5] = "wave5" },
		endCard = {
			title = "CHAPTER 1 COMPLETE — Crossroads Restored!",
			teaser = "Next time... Chapter 2: The Haunted Mansion of 1x1x1x1.",
			thanks = "Thanks for testing the '08 Alpha. Your save is in the cloud.",
		},
	},
}

return Chapters
