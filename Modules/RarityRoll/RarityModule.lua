local rarityScript = {}

rarityScript.Rarity = {"Common", "Uncommon", "Rare", "Very Rare", "Legendary"}

rarityScript.RaritiesChances= {
	["Common"] = 60, 
	["Uncommon"] = 25,
	["Rare"] = 8,
	["Very Rare"] = 5,
	["Legendary"] = 2}

rarityScript.RaritiesPool = {
	["Common"] = {"Common1","Common2"},
	["Uncommon"] = {"Uncommon1","Uncommon2"},
	["Rare"] = {"Rare1","Rare2"},
	["Very Rare"] = {"VeryRare1","VeryRare2"},
	["Legendary"] = {"Legendary1","Legendary2"}
}


function rarityScript.rollRarity()
	local roll = math.random(1,100)
	local acummulative = 0
	print(roll)
			
	for _, rarity in ipairs(rarityScript.Rarity) do
	  acummulative = acummulative + rarityScript.RaritiesChances[rarity] 
		if roll <= acummulative then
		  print(rarity)
			return rarity
		end
	end
end
	
function rarityScript.rollItem(rarity)
	local pool = rarityScript.RaritiesPool[rarity]
	local roll = math.random(1,#pool)
	return pool[roll]
		
end


--print(rarityScript.rollRarity())
print(rarityScript.rollItem(rarityScript.rollRarity()))

return rarityScript