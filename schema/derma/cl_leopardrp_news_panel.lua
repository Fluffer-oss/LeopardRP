-- LeopardRP Main Menu News Panel
-- Add news content by editing LeopardRP.NewsPanel.Pages table

LeopardRP = LeopardRP or {}
LeopardRP.NewsPanel = LeopardRP.NewsPanel or {}

-- Customize news pages here
LeopardRP.NewsPanel.Pages = LeopardRP.NewsPanel.Pages or {
	{
		title = "Welcome to LeopardRP",
		description = "Welcome to the LeopardRP Star Trek roleplay server. Work together with other players to explore the galaxy and create memorable experiences.\n\nUse F9 to access the main menu.",
		link = ""
	},
	{
		title = "Character Creation",
		description = "Create your character by selecting your species, division, and rank. Customize your appearance to make your character unique.\n\nYour character will be saved to your profile.",
		link = ""
	},
	{
		title = "Server Rules",
		description = "Please respect all players and follow server rules. Report rule violations to staff immediately.\n\nHave fun and enjoy the roleplay experience!",
		link = ""
	}
}

local PANEL = {}
local FONT_TITLE = "LeopardRP.Menu.PanelBold"
local FONT_BODY = "LeopardRP.Menu.Small"
local FONT_FOOTER = "LeopardRP.Menu.Micro"

-- Text layout tuning (edit these values only).
local NEWS_TEXT_TUNING = {
	leftPadding = 10,
	-- Right inset from panel border for description text region.
	descriptionRightInset = 0,
	-- 0.10 to 1.00. 1.00 reaches the right edge region of the panel.
	descriptionWidthScale = 1.00,
	descriptionXOffset = 0,
	titleTop = 12,
	descriptionTop = 45,
	descriptionBottomPadding = 24,
	footerSpacing = 16,
	lineSpacing = 2,
}

local function GetDescriptionBounds(panelWidth)
	local contentLeftBase = (tonumber(NEWS_TEXT_TUNING.leftPadding) or 0) + (tonumber(NEWS_TEXT_TUNING.descriptionXOffset) or 0)
	local contentRight = panelWidth - math.max(0, tonumber(NEWS_TEXT_TUNING.descriptionRightInset) or 0)
	local maxWidth = math.max(32, contentRight - contentLeftBase)
	local scale = tonumber(NEWS_TEXT_TUNING.descriptionWidthScale) or 1
	scale = math.max(0.10, math.min(1.00, scale))

	-- Anchor the region to the right border so 1.0 always reaches the edge.
	local width = math.max(32, math.floor(maxWidth * scale))
	local contentLeft = contentRight - width

	if contentLeft < contentLeftBase then
		contentLeft = contentLeftBase
		width = math.max(32, contentRight - contentLeft)
	end

	return contentLeft, width
end

function PANEL:Init()
	self.Pages = LeopardRP.NewsPanel.Pages or {}
	self.CurrentPage = 1
	self.TargetPage = (#self.Pages > 0) and 1 or 0
	self.PageFade = 1
	self.NextSwitchAt = CurTime() + 6
	self.IndicatorBoxes = {}
	self:SetTall(220)
end

local function WrapText(text, font, maxWidth)
	maxWidth = math.max(1, tonumber(maxWidth) or 1)
	surface.SetFont(font)

	local function splitLongToken(token)
		local chunks = {}
		local chunk = ""

		for index = 1, #token do
			local ch = token:sub(index, index)
			local candidate = chunk .. ch
			local candidateWidth = tonumber(surface.GetTextSize(candidate)) or 0

			if candidateWidth > maxWidth and chunk ~= "" then
				table.insert(chunks, chunk)
				chunk = ch
			else
				chunk = candidate
			end
		end

		if chunk ~= "" then
			table.insert(chunks, chunk)
		end

		return chunks
	end

	local lines = {}
	for paragraph in tostring(text or ""):gmatch("([^\n]*)\n?") do
		if paragraph == "" then
			table.insert(lines, "")
		else
			local currentLine = ""
			for word in paragraph:gmatch("%S+") do
				local token = word
				local tokenWidth = tonumber(surface.GetTextSize(token)) or 0
				local handledLongToken = false

				if tokenWidth > maxWidth then
					local splitWords = splitLongToken(token)
					for _, piece in ipairs(splitWords) do
						if currentLine ~= "" then
							table.insert(lines, currentLine)
							currentLine = ""
						end
						table.insert(lines, piece)
					end
					handledLongToken = true
				end

				if not handledLongToken then
					local candidate = currentLine == "" and token or currentLine .. " " .. token
					local candidateWidth = tonumber(surface.GetTextSize(candidate)) or 0
					if candidateWidth > maxWidth and currentLine ~= "" then
						table.insert(lines, currentLine)
						currentLine = token
					else
						currentLine = candidate
					end
				end
			end

			if currentLine ~= "" then
				table.insert(lines, currentLine)
			end
		end
	end

	if #lines == 0 then
		lines[1] = ""
	end

	return lines
end

local function GetPageLink(page)
	if not istable(page) then
		return ""
	end

	return tostring(page.link or page.url or "")
end

function PANEL:AdvancePage()
	if #self.Pages <= 1 then return end

	self.TargetPage = self.CurrentPage + 1
	if self.TargetPage > #self.Pages then
		self.TargetPage = 1
	end

	self.PageFade = 0
	self.NextSwitchAt = CurTime() + 6
end

function PANEL:Think()
	if #self.Pages > 1 and CurTime() >= (self.NextSwitchAt or 0) then
		self:AdvancePage()
	end

	if self.PageFade < 1 then
		self.PageFade = math.min(1, self.PageFade + FrameTime() * 3.5)
		if self.PageFade >= 1 then
			self.CurrentPage = self.TargetPage
		end
	end
end

function PANEL:Paint(w, h)
	local page = self.Pages[self.CurrentPage] or self.Pages[1] or {}
	local target = self.Pages[self.TargetPage] or page
	local fade = self.PageFade or 1
	local pageLink = GetPageLink(target)
	local footerVisible = pageLink ~= ""
	local accent = ix.config.Get("color") or Color(75, 119, 190, 255)

	-- Keep body subtle and let the perimeter do the visual integration.
	draw.RoundedBox(6, 0, 0, w, h, Color(8, 12, 20, 24))

	for y = 0, h - 1 do
		local frac = y / math.max(1, h - 1)
		local alpha = math.floor(8 + 175 * (frac ^ 1.35))
		surface.SetDrawColor(accent.r, accent.g, accent.b, alpha)
		surface.DrawRect(0, y, 1, 1)
		surface.DrawRect(w - 1, y, 1, 1)
	end

	local topAlpha = 16
	local bottomAlpha = 200
	surface.SetDrawColor(accent.r, accent.g, accent.b, topAlpha)
	surface.DrawRect(0, 0, w, 1)
	surface.SetDrawColor(accent.r, accent.g, accent.b, bottomAlpha)
	surface.DrawRect(0, h - 1, w, 1)

	local titleAlpha = math.floor(255 * fade)
	draw.SimpleText(target.title or page.title or "News", FONT_TITLE, NEWS_TEXT_TUNING.leftPadding, NEWS_TEXT_TUNING.titleTop, Color(200, 220, 255, titleAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	local description = target.description or page.description or ""
	local contentLeft, descriptionWidth = GetDescriptionBounds(w)
	local descriptionLines = WrapText(description, FONT_BODY, descriptionWidth)
	surface.SetFont(FONT_BODY)
	local lineHeight = select(2, surface.GetTextSize("Hg")) + NEWS_TEXT_TUNING.lineSpacing
	local descriptionTop = NEWS_TEXT_TUNING.descriptionTop
	local descriptionBottom = h - NEWS_TEXT_TUNING.descriptionBottomPadding - (footerVisible and NEWS_TEXT_TUNING.footerSpacing or 0)
	local maxLines = math.max(0, math.floor((descriptionBottom - descriptionTop) / lineHeight))

	for index = 1, math.min(#descriptionLines, maxLines) do
		local lineText = descriptionLines[index]
		if index == maxLines and #descriptionLines > maxLines then
			lineText = string.gsub(lineText or "", "%s+$", "") .. "..."
		end

		draw.SimpleText(lineText, FONT_BODY, contentLeft, descriptionTop + (index - 1) * lineHeight, Color(180, 190, 210, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	-- Indicators
	local indicatorY = h - 24
	self.IndicatorBoxes = {}
	for index = 1, math.max(3, #self.Pages) do
		local active = index == self.CurrentPage
		local indicatorX = 18 + (index - 1) * 14
		local indicatorColor = active and Color(accent.r, accent.g, accent.b, 255) or Color(80, 100, 140, 200)
		draw.RoundedBox(2, indicatorX, indicatorY, 10, 5, indicatorColor)

		self.IndicatorBoxes[index] = {
			x = indicatorX,
			y = indicatorY,
			w = 10,
			h = 5
		}
	end

	if footerVisible then
		draw.SimpleText("Click for more information", FONT_FOOTER, w - 18, h - 14, Color(150, 180, 255, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	end
end

function PANEL:OnMousePressed(mouseCode)
	if mouseCode ~= MOUSE_LEFT then return end

	local localX, localY = self:LocalCursorPos()

	for index, box in ipairs(self.IndicatorBoxes or {}) do
		if (index <= #self.Pages and localX >= box.x and localX <= (box.x + box.w) and localY >= box.y and localY <= (box.y + box.h)) then
			self.CurrentPage = index
			self.TargetPage = index
			self.PageFade = 1
			self.NextSwitchAt = CurTime() + 6
			return
		end
	end

	local page = self.Pages[self.CurrentPage] or self.Pages[1] or {}
	local pageLink = GetPageLink(page)
	if pageLink ~= "" then
		gui.OpenURL(pageLink)
	end
end

vgui.Register("LeopardRPNewsPanel", PANEL, "DPanel")
