import Lean

def prelude : Bool → List String
  | true =>
    [
      "# automatically inserted by LeanTex, DO NOT MODIFY",
      "[[lean_exe]]",
      "name = \"GenerateSlides\"",
      "root = \"GenerateSlides\""
    ]
  | false =>
    [
      "-- automatically inserted by LeanTex, DO NOT MODIFY",
      "lean_exe GenerateSlides where",
      "  root := `GenerateSlides"
    ]

def containsLeanExeDecl (s: String) (isToml: Bool) :=
  s.splitOn "\n"
  |>.findSome? (·.trimAscii.dropPrefix? (if isToml then "name = \"GenerateSlides\"" else "lean_exe GenerateSlides where"))
  |>.isSome

def extractDeps (s: String) : Bool → List String
  | true =>
    s.splitOn "[["
    |>.filterMap (·.dropPrefix? "lean_lib]]\nname = \"")
    |>.filterMap (·.trimAscii.toString |>.split "\"" |>.toStringList |>.head?)
  | false =>
    s.splitOn "\n"
    |>.map (·.trimAscii)
    |>.filterMap (·.dropPrefix? "lean_lib ")
    |>.filterMap (·.trimAscii.toString |>.split " " |>.toStringList |>.head?)

def generateSlidesLean (deps: List String) :=
   let importDeps :=
       deps.map (fun dep => s!"import {dep}")
       |> String.intercalate "\n"
s!"
{importDeps}
import GenerateSlidesLib

#leantex_config latexConfig

unsafe def main : IO Unit := do
   generateSlides latexConfig
"

def lakefileToml : System.FilePath := "lakefile.toml"
def lakefileLean : System.FilePath := "lakefile.lean"
def GenerateSlides : System.FilePath := "GenerateSlides.lean"

def main : IO Unit := do
  let isToml <- lakefileToml.pathExists

  if !isToml && !(<- lakefileLean.pathExists) then
    throw <| IO.userError s!"lakefile not found"

  let lakefile := if isToml then lakefileToml else lakefileLean
  let lakefileContents <- IO.FS.readFile lakefile
  let libs := extractDeps lakefileContents isToml

  if !(<- GenerateSlides.pathExists) then
     IO.FS.writeFile GenerateSlides <| generateSlidesLean libs

  if !(containsLeanExeDecl lakefileContents isToml) then
     IO.FS.writeFile lakefile <|
        lakefileContents
        ++ "\n"
        ++ String.intercalate "\n" (prelude isToml)
     let _ <- IO.Process.spawn {
        cmd := "lake",
        args := #["exe", "GenerateSlides"]
     }
