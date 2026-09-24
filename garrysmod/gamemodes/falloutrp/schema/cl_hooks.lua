-- Clientside schema hooks.

function Schema:CharacterLoaded(character)
	self:ExampleFunction("@serverWelcome", character:GetName())
end
