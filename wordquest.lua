local mq = require('mq')
require 'ImGui'

math.randomseed(os.time())
-- GUI Control variables
local openGUI = true
local shouldDrawGUI = true
local terminate = false

-- mqwords.lua contains a shorter list of more common words to use as possible results
local words = require('wordquestwords')

-- sgb-words.txt contains a larger list of words to use for valid input words
local f = mq.luaDir..'/wordquestvalid.txt'
local valid_inputs = {}
for line in io.lines(f) do
    valid_inputs[line] = 1
end

local r -- random word index
local word -- the winning word
local word_letters -- individual letters of the winning word
local gameover -- true if result found or 6 turns used
local turn -- current turn
local board -- the game board
local guess -- the current guess input
local guess_letters -- individual letters of the current guess input
local selected = false

local function reset_board()
    board = {
        {'.','.','.','.','.',},
        {'.','.','.','.','.',},
        {'.','.','.','.','.',},
        {'.','.','.','.','.',},
        {'.','.','.','.','.',},
        {'.','.','.','.','.',},
        {'.','.','.','.','.',},
    }
    gameover = false
    turn = 1
    r = math.random(1, #words)
    word = words[r]:upper()
    word_letters = {[word:sub(1,1)]=1,[word:sub(2,2)]=1,[word:sub(3,3)]=1,[word:sub(4,4)]=1,[word:sub(5,5)]=1,}
    guess = ''
    guess_letters = {}
end
reset_board()

local letters = {
    {'Q','W','E','R','T','Y','U','I','O','P',},
    {'A','S','D','F','G','H','J','K','L',},
    {'Z','X','C','V','B','N','M',},
}

local function push_styles()
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 1)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, 0, .3, .3, 1)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0, .5, .5, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.Button, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.Separator, 0, .4, .4, 1)
end

local function draw_header()
    if turn > 1 and turn <= 7 and table.concat(board[turn-1], '') == word then
        ImGui.SetCursorPosX(125)
        ImGui.Text('Winner!')
        gameover = true
    end
    if turn > 6 and not gameover then
        gameover = true
        ImGui.SetCursorPosX(125)
        ImGui.Text('Loser!')
    end
    ImGui.SetCursorPosX(125)
    if ImGui.Button('Reset') then
        reset_board()
    end
end

local function draw_board()
    for i=1,6 do
        ImGui.SetCursorPosX(55)
        for j=1,5 do
            local id = tostring(i)..tostring(j)
            if board[i][j] == string.sub(word, j, j) then
                ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                ImGui.Button(board[i][j]..'##'..id, 30, 30)
                ImGui.PopStyleColor()
            elseif word_letters[board[i][j]] then
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
                ImGui.Button(board[i][j]..'##'..id, 30, 30)
                ImGui.PopStyleColor()
            else
                ImGui.Button(board[i][j]..'##'..id, 30, 30)
            end
            ImGui.SameLine()
        end
        ImGui.NewLine()
    end
end

local function draw_input()
    ImGui.SetCursorPosX(55)
    ImGui.SetNextItemWidth(183)
    if not gameover then
        guess, selected = ImGui.InputText('##input', guess, ImGuiInputTextFlags.EnterReturnsTrue)
        if selected and valid_inputs[guess:lower()] then
            guess = guess:upper()
            for i=1,5 do
                board[turn][i] = string.sub(guess, i, i)
                guess_letters[board[turn][i]] = 1
            end
            turn = turn + 1
        end
    end
end

local function draw_letters()
    for i,j in ipairs(letters) do
        if i == 2 then
            ImGui.SetCursorPosX(22)
        elseif i == 3 then
            ImGui.SetCursorPosX(50)
        end
        for k,l in ipairs(j) do
            local id = tostring(i)..tostring(k)
            if guess_letters[l] and word_letters[l] then
                ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                ImGui.Button(l..'##letter'..id, 20, 20)
                ImGui.PopStyleColor()
            elseif guess_letters[l] then
                ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                ImGui.Button(l..'##letter'..id, 20, 20)
                ImGui.PopStyleColor()
            else
                ImGui.Button(l..'##letter'..id, 20, 20)
            end
            ImGui.SameLine()
        end
        ImGui.NewLine()
    end
end

-- ImGui main function for rendering the UI window
local wordle = function()
    push_styles()
    openGUI, shouldDrawGUI = ImGui.Begin('WordQuest', openGUI, ImGuiWindowFlags.AlwaysAutoResize)
    if shouldDrawGUI then
        draw_header()
        ImGui.Separator()
        draw_board()
        ImGui.Separator()
        draw_input()
        ImGui.Separator()
        draw_letters()
    end
    ImGui.End()
    ImGui.PopStyleColor(10)
    if not openGUI then
        terminate = true
    end
end

mq.imgui.init('wordle', wordle)

while not terminate do
    mq.delay(1000)
end
