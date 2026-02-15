if true then
	error("Do not load this file, nooben")
	return
end

--- @class MenuOptions
--- @field addOption fun(plugin: string, option: string, default: string)
--- @field getOption fun(plugin: string, option: string): string
--- @field setOption fun(plugin: string, option: string, value: string)
--- @field getTable fun(): table<string, table>

--- @class MenuPlugins
--- @field sidebar Panel
--- @field options MenuOptions

--- @class Interstate
--- @field DEBUG boolean
--- @field GetIP fun(): string
--- @field IsClientValid fun(): boolean
--- @field IsServerValid fun(): boolean
--- @field RequireOnClient fun(Name: string)
--- @field RunOnClient fun(Code: string, Name: string|nil, HandleError: boolean|nil)
--- @field RunOnServer fun(Code: string, Name: string|nil, HandleError: boolean|nil)
--- @field editor Panel|nil
--- @field frame Panel|nil

--- @class _G
--- @field menup MenuPlugins
--- @field interstate Interstate
