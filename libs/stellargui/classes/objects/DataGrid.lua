-- datagrid
local datagrid = {}

local complex = require("classes.CompositeObject")
local textfield = require("classes.objects.TextField")
local uiobj = require("classes.ObjectUI")

-- documentation



-- consts

local TEXT_OFFSET_LEFT = 5
local TEXT_OFFSET_TOP = 5

local SAMPLE_TEXT = string.rep(" ", 8)

-- config

local function datagridSizeProcessor(_, sink)
    if sink.cellSize and sink.cellSize[1] and sink.cellSize[2] then -- Cell size is defined, object size is not
        print("Cell size is defined, object size is not")

        sink.w, sink.h = sink.cellSize[1] * sink.gridSize[1], sink.cellSize[2] * sink.gridSize[2]
    elseif sink.w then -- Object size is defined, but cell size is to be calculated
        print("Object size is defined, but cell size is to be calculated")
    
        sink.cellSize = {
            math.floor(sink.w/sink.gridSize[1]),
            math.floor(sink.h/sink.gridSize[2])
        }
    else -- Only grid resolution is defined, neither cell size nor object size are defined
        print("Only grid resolution is defined, neither cell size nor object size are defined")

        sink.cellSize = {
            sink.font:getWidth(SAMPLE_TEXT) + TEXT_OFFSET_LEFT*2,
            sink.font:getHeight() + TEXT_OFFSET_TOP*2
        }

        sink.w, sink.h = sink.cellSize[1] * sink.gridSize[1], sink.cellSize[2] * sink.gridSize[2]
    end

    if not sink.table then
        sink.table = {}
        for i = 1, sink.gridSize[1] do
            sink.table[i] = {}
        end
    end
end

datagrid.name = "DataGrid"
datagrid.aliases = {}
datagrid.rules = {
    {{"font"}, "font", love.graphics.getFont()},
    {{"table", "data", "content", "contents"}, "table"}, -- Default table is created in datagridSizeProcessor

    {{"grid", "gridSize", "grid_size", "gridResolution", "grid_resolution"}, "gridSize", {5, 5}},
    {"sizeRectangular", {nil}},
    {{"cell", "cellSize", "cell_size", "cellResolution", "cell_resolution"}, "cellSize", nil},
    datagridSizeProcessor,

    {"position", {position = {"center", "center"}}},

    {"palette", {color = {1, 1, 1, 1}, textColor = {0, 0, 0, 1}, frameColor = {0.5, 0.5, 0.5, 1}}},
}

-- vars



-- init



-- fnc



-- classes

---@class DataPlain : ObjectUI
---@field font love.Font
---@field gridSize {[1]: integer, [2]: integer} DataGrid resolution in {Columns, Lines}
---@field cellSize {[1]: number, [2]: number} Cell size in pixels[2]
---@field table table<integer, table<integer, (string|number)?>> 2D-array of datagrid contents
---@field ow integer Original width
---@field oh integer Original height
---@field parent DataGrid
local DataPlain = {}
local DataPlain_meta = {__index = DataPlain}
setmetatable(DataPlain, {__index = uiobj.class}) -- Set parenthesis

function DataPlain:paint()
    for column = 0, self.gridSize[1] - 1 do
        for row = 0, self.gridSize[2] - 1 do
            love.graphics.setColor(self.palette[1])
            love.graphics.rectangle("fill", column * self.cellSize[1], row * self.cellSize[2], self.cellSize[1], self.cellSize[2])

            love.graphics.setColor(self.palette[3])
            love.graphics.rectangle("line", column * self.cellSize[1], row * self.cellSize[2], self.cellSize[1], self.cellSize[2])

            if self.table[column + 1][row + 1] then
                love.graphics.setColor(self.palette[2])
                love.graphics.setFont(self.font)
                love.graphics.printf(self.table[column + 1][row + 1], column * self.cellSize[1] + TEXT_OFFSET_LEFT, row * self.cellSize[2] + TEXT_OFFSET_TOP, self.cellSize[1] - 2*TEXT_OFFSET_LEFT, "center")
            end
        end
    end
end

function DataPlain:click(x, y, _)
    if self.parent.editedCell then
        self.parent:endEdit()
    end

    local insideX, insideY = x + 1 - self.x, y + 1 - self.y
    local clickedColumn, clickedRow = math.ceil(insideX/self.cellSize[1]), math.ceil(insideY/self.cellSize[2])

    self.parent:selectCell(clickedColumn, clickedRow)
end

function DataPlain:keyPress(key)
    if self.parent.editedCell then
        local edited = self.parent.editedCell ---@cast edited {[1]: integer, [2]: integer}

        if key == "escape" then
            self.parent:endEdit(true)
            self:revokeFocus()
        elseif key == "tab" then
            self.parent:selectCell(edited[1] + 1, edited[2])
            return
        elseif key == "return" then
            self:revokeFocus(self.parent.editTextField)
        elseif key == "up" and edited[2] > 1 then
            self.parent:selectCell(edited[1], edited[2] - 1)
        elseif key == "down" and edited[2] < self.gridSize[2] then
            self.parent:selectCell(edited[1], edited[2] + 1)
        elseif key == "left" and edited[1] > 1 then
            self.parent:selectCell(edited[1] - 1, edited[2])
        elseif key == "right" and edited[1] < self.gridSize[1] then
            self.parent:selectCell(edited[1] + 1, edited[2])
        end
    end
end

local function newDataPlain(prototype)
    local obj = uiobj.new(prototype)
    setmetatable(obj, DataPlain_meta)---@cast obj DataPlain

    obj.ow, obj.oh = obj:getResolution()

    return obj
end

---@class DataGridTextField : TextField
---@field parent DataGrid
local DataGridTextField = { oneline = true }
local DataGridTextField_meta = {__index = DataGridTextField}
setmetatable(DataGridTextField, {__index = textfield.class}) -- Set parenthesis

function DataGridTextField:keyPress(key)
    if self.parent.editedCell then
        if key == "escape" then
            self:revokeFocus(self.parent.gridDataPlain)
            self.parent:selectCell(self.parent.editedCell[1], self.parent.editedCell[2])
            return
        elseif key == "tab" then
            local edited = self.parent.editedCell ---@cast edited {[1]: integer, [2]: integer}
            self.parent:endEdit()
            self:revokeFocus(self.parent.gridDataPlain)

            self.parent:selectCell(edited[1] + 1, edited[2])
            return
        end
    end

    textfield.class.keyPress(self, key)
end

function DataGridTextField:hoverOn(x, y)
    textfield.class.hoverOn(self, x, y)

    return self.focus and "ibeam" or "arrow"
end

function DataGridTextField:gainFocus()
    textfield.class.gainFocus(self)
    if self.hl then
        self:setCursor("ibeam")
    end
end

function DataGridTextField:loseFocus()
    textfield.class.loseFocus(self)
    self:setCursor("arrow")

    if self.parent.editedCell then
        self.parent:endEdit()
    end

    self:hide()
end

function DataGridTextField:action()
    local edited = self.parent.editedCell ---@cast edited {[1]: integer, [2]: integer}
    self.parent:endEdit()
    self:revokeFocus(self.parent.gridDataPlain)
    self.parent:selectCell(edited[1], edited[2] + 1)
end

local function newDataGridTextField(prototype)
    local obj = textfield.new{
        x = prototype.x,
        y = prototype.y,
        w = prototype.cellSize[1],
        h = prototype.cellSize[2],
        palette = {prototype.palette[1], prototype.palette[2], {0, 0, 1, 1}},
        font = prototype.font,
        text = ""
    }
    setmetatable(obj, DataGridTextField_meta)---@cast obj DataGridTextField

    obj:hide()

    return obj
end

---@class DataGrid : CompositeObject
---@field gridDataPlain DataPlain DataPlain object used for displaying datagrid cells
---@field editTextField TextField TextField object used for editing datagrid cells
---@field editedCell {[1]: integer, [2]: integer}? Cell that is currently being edited. Nil, if no cells are being edited
local DataGrid = {}
local DataGrid_meta = {__index = DataGrid}
setmetatable(DataGrid, {__index = complex.class}) -- Set parenthesis
datagrid.class = DataGrid

---Start the process of editing the cell
---@param column integer
---@param row integer
function DataGrid:selectCell(column, row)
    local column, row = column, row

    if row <= self.gridDataPlain.gridSize[2] then
        if column > self.gridDataPlain.gridSize[1] then
            column = 1

            if row == self.gridDataPlain.gridSize[2] then
                row = 1
            else
                row = row + 1
            end
        end
    else
        if column > self.gridDataPlain.gridSize[1] then
            column, row = self.gridDataPlain.gridSize[1], self.gridDataPlain.gridSize[2]
        else
            row = row - 1
        end
    end

    self.editedCell = {column, row}

    self.editTextField:move(self.x + (column - 1)*self.gridDataPlain.cellSize[1], self.y + (row - 1)*self.gridDataPlain.cellSize[2])
    self.editTextField:setText(self.gridDataPlain.table[column][row] or "")
    self.editTextField:show()
end

function DataGrid:endEdit(cancel)
    if not cancel then
        local newText = self.editTextField:getText()
        self.gridDataPlain.table[self.editedCell[1]][self.editedCell[2]] = tonumber(newText) or newText
    end
    self.editTextField:hide()
    self.editedCell = nil
end

function DataGrid:set(column, row, content)
    self.gridDataPlain.table[column][row] = content
end

function DataGrid:resize(columns, rows)
    self:endEdit(true)
    if columns > self.gridDataPlain.gridSize[1] then
        for i = self.gridDataPlain.gridSize[1] + 1, columns do
            self.gridDataPlain.table[i] = {}
        end
    end

    if rows > self.gridDataPlain.gridSize[2] then
        for i = 1, self.gridDataPlain.gridSize[1] do
            self.gridDataPlain.table[i][rows] = nil
        end
    end

    self.gridDataPlain.gridSize = {columns, rows}

    self.gridDataPlain.cellSize = {math.floor(self.gridDataPlain.ow/columns), math.floor(self.gridDataPlain.oh/rows)}
    self.editTextField.w = self.gridDataPlain.cellSize[1]
    self.editTextField.h = self.gridDataPlain.cellSize[2]
end

-- textfield fnc

---Create new TextField object from object prototype
---@param prototype ObjectPrototype
---@return DataGrid
function datagrid.new(prototype)
    local obj = complex.new{x = prototype.x, y = prototype.y, w = prototype.w, h = prototype.h}
    setmetatable(obj, DataGrid_meta)---@cast obj DataGrid

    obj.gridDataPlain = newDataPlain(prototype)
    obj:add(obj.gridDataPlain)

    obj.editTextField = newDataGridTextField(prototype)
    obj:add(obj.editTextField)

    return obj
end

return datagrid