--!strict
-- SHA-256 tegen de bekende testvectoren. Als deze kloppen, klopt de hash, en dan is de
-- belofte die de server voor een crashronde publiceert ook echt na te rekenen.
local Sha256 = require("../src/shared/Sha256")
local h = require("./harness")

h.check("lege tekst",
	"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
	Sha256.hash(""))
h.check("abc",
	"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
	Sha256.hash("abc"))
h.check("448 bits",
	"248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
	Sha256.hash("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))
h.check("896 bits",
	"cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1",
	Sha256.hash("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"))
h.check("een miljoen letters a",
	"cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0",
	Sha256.hash(string.rep("a", 1000000)))
-- Precies op een blokgrens: dat is de plek waar een verkeerde vulling stukgaat.
h.check("64 tekens",
	"ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb",
	Sha256.hash(string.rep("a", 64)))
h.check("55 tekens", Sha256.hash(string.rep("a", 55)), Sha256.hash(string.rep("a", 55)))
h.check("een zaad met streepjes geeft 64 hexcijfers", 64, #Sha256.hash("1700000000-1-123-456"))

-- De belofte is gewoon de hash van "commit:" plus het zaad; dat moet iedereen kunnen
-- narekenen zonder de code te hebben.
h.check("commit is hash van commit: plus zaad",
	Sha256.hash("commit:mijn-zaad"), Sha256.commit("mijn-zaad"))

-- Van hash naar een getal tussen 0 en 1.
local u = Sha256.unit(Sha256.hash("abc"))
h.check("unit ligt tussen 0 en 1", true, u >= 0 and u < 1)
h.check("unit is stabiel", u, Sha256.unit(Sha256.hash("abc")))
h.check("een ander zaad geeft een ander getal", true, u ~= Sha256.unit(Sha256.hash("abd")))

-- Twee zaden achter elkaar mogen nooit gelijk zijn.
local a, b = Sha256.seed(), Sha256.seed()
h.check("twee zaden verschillen", true, a ~= b)

h.report("SHA-256")
