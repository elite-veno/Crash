--!strict
-- Laadt een module uit src zonder Studio, en houdt een simpele testtelling bij.
local harness = {}

local passed, failed = 0, 0
local fouten: { string } = {}

function harness.check(naam: string, verwacht: any, kreeg: any)
	if verwacht == kreeg then
		passed += 1
	else
		failed += 1
		table.insert(fouten, string.format("%s | verwacht %s kreeg %s", naam, tostring(verwacht), tostring(kreeg)))
	end
end

function harness.near(naam: string, verwacht: number, kreeg: number, marge: number?)
	local m = marge or 1e-9
	if math.abs(verwacht - kreeg) <= m then
		passed += 1
	else
		failed += 1
		table.insert(fouten, string.format("%s | verwacht %.6f kreeg %.6f", naam, verwacht, kreeg))
	end
end

function harness.report(titel: string): never
	print(string.format("%s: %d geslaagd, %d gefaald", titel, passed, failed))
	for _, f in fouten do
		print("  FAIL " .. f)
	end
	if failed > 0 then
		error(string.format("%d test(s) gefaald", failed), 0)
	end
	return nil :: any
end

return harness
