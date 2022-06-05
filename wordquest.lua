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
local board = {} -- the game board
local guess -- the current guess input
local guess_letters -- individual letters of the current guess input
local selected = false
local views = {BOARD=1,STATS=2}
local current_view = views.BOARD
local word_length = 5
local max_turns = 6
local empty_tile = ''

local stats = {
    played=0,
    wins=0,
    losses=0,
}
for i=1,max_turns do
    stats[i]=0
end

local function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

local function reset_board()
    for i=1,max_turns do
        board[i]={}
        for j=1,word_length do board[i][j]=empty_tile end
    end
    gameover = false
    turn = 1
    r = math.random(1, #words)
    word = words[r]:upper()
    word_letters = {}
    for i=1,word_length do
        word_letters[word:sub(i,i)]=1
    end
    guess = ''
    guess_letters = {}
end

-- table serialization
local function exportstring(s)
    return string.format("%q", s)
end

--// The Save Function
function table.save(tbl, filename)
    local charS,charE = "   ","\n"
    local file,err = io.open( filename, "wb" )
    if err then return err end

    -- initiate variables for save procedure
    local tables,lookup = { tbl },{ [tbl] = 1 }
    file:write( "return {"..charE )

    for idx,t in ipairs( tables ) do
        file:write( "-- Table: {"..idx.."}"..charE )
        file:write( "{"..charE )
        local thandled = {}

        for i,v in ipairs( t ) do
            thandled[i] = true
            local stype = type( v )
            -- only handle value
            if stype == "table" then
                if not lookup[v] then
                    table.insert( tables, v )
                    lookup[v] = #tables
                end
                file:write( charS.."{"..lookup[v].."},"..charE )
            elseif stype == "string" then
                file:write(  charS..exportstring( v )..","..charE )
            elseif stype == "number" then
                file:write(  charS..tostring( v )..","..charE )
            end
        end

        for i,v in pairs( t ) do
            -- escape handled values
            if (not thandled[i]) then

                local str = ""
                local stype = type( i )
                -- handle index
                if stype == "table" then
                    if not lookup[i] then
                        table.insert( tables,i )
                        lookup[i] = #tables
                    end
                    str = charS.."[{"..lookup[i].."}]="
                elseif stype == "string" then
                    str = charS.."["..exportstring( i ).."]="
                elseif stype == "number" then
                    str = charS.."["..tostring( i ).."]="
                end

                if str ~= "" then
                    stype = type( v )
                    -- handle value
                    if stype == "table" then
                        if not lookup[v] then
                            table.insert( tables,v )
                            lookup[v] = #tables
                        end
                        file:write( str.."{"..lookup[v].."},"..charE )
                    elseif stype == "string" then
                        file:write( str..exportstring( v )..","..charE )
                    elseif stype == "number" then
                        file:write( str..tostring( v )..","..charE )
                    end
                end
            end
        end
        file:write( "},"..charE )
    end
    file:write( "}" )
    file:close()
end

function table.load(sfile)
    local ftables,err = loadfile( sfile )
    if err then return _,err end
    local tables = ftables()
    for idx = 1,#tables do
        local tolinki = {}
        for i,v in pairs( tables[idx] ) do
            if type( v ) == "table" then
                tables[idx][i] = tables[v[1]]
            end
            if type( i ) == "table" and tables[i[1]] then
                table.insert( tolinki,{ i,tables[i[1]] } )
            end
        end
        -- link indices
        for _,v in ipairs( tolinki ) do
            tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
        end
    end
    return tables[1]
end
-- end table serialization

local function push_styles()
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 1)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, 0, .3, .3, 1)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0, .5, .5, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.Button, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, .4, .4, .4, 1)
    ImGui.PushStyleColor(ImGuiCol.Separator, 0, .4, .4, 1)
end

local function record_win()
    stats.played = stats.played + 1
    stats.wins = stats.wins + 1
    stats[turn-1] = stats[turn - 1] + 1
    gameover = true
    table.save(stats, mq.configDir..'/wordquest.lua')
end

local function record_loss()
    stats.played = stats.played + 1
    stats.losses = stats.losses + 1
    gameover = true
    table.save(stats, mq.configDir..'/wordquest.lua')
end

local function draw_stats()
    if ImGui.Button('Return to Board', 280, 30) then
        current_view = views.BOARD
    end
    ImGui.Separator()
    ImGui.Text('Games Played: ' .. stats.played)
    ImGui.TextColored(0, 1, 0, 1, 'Wins: ' .. stats.wins)
    ImGui.TextColored(1, 0, 0, 1, 'Losses: ' .. stats.losses)
    ImGui.Text('Won in...')
    for i=1,max_turns do
        ImGui.Text(string.format('%d turn(s): %d', i, stats[i]))
    end
end

local function draw_header()
    if turn > 1 and turn <= max_turns + 1 and table.concat(board[turn-1], '') == word then
        ImGui.SetCursorPosX(125)
        ImGui.Text('Winner!')
        if not gameover then record_win() end
    end
    if turn > max_turns and not gameover then
        ImGui.SetCursorPosX(125)
        ImGui.Text('Loser!')
        if not gameover then record_loss() end
    end
    ImGui.SetCursorPosX(105)
    if ImGui.Button('Reset') then
        reset_board()
    end
    ImGui.SameLine()
    if ImGui.Button('Stats') then
        current_view = views.STATS
    end
end

local function draw_board()
    for i=1,max_turns do
        ImGui.SetCursorPosX(55)
        for j=1,word_length do
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
            for i=1,word_length do
                board[turn][i] = string.sub(guess, i, i)
                guess_letters[board[turn][i]] = 1
            end
            turn = turn + 1
        end
    end
end

local letters = {
    {'Q','W','E','R','T','Y','U','I','O','P',},
    {'A','S','D','F','G','H','J','K','L',},
    {'Z','X','C','V','B','N','M',},
}
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
        if current_view == views.BOARD then
            draw_header()
            ImGui.Separator()
            draw_board()
            ImGui.Separator()
            draw_input()
            ImGui.Separator()
            draw_letters()
        else
            draw_stats()
        end
    end
    ImGui.End()
    ImGui.PopStyleColor(10)
    if not openGUI then
        terminate = true
    end
end

reset_board()
if file_exists(mq.configDir..'/wordquest.lua') then
    stats = table.load(mq.configDir..'/wordquest.lua')
end

mq.imgui.init('wordle', wordle)

while not terminate do
    mq.delay(1000)
end
