import Lean

def prelude : List String := [
   "-- automatically inserted by LeanTex, DO NOT MODIFY",
   "lean_exe GenerateSlides where",
   "  root := `GenerateSlides"
]

def containsLeanExeDecl (s: String) :=
  s.splitOn "\n"
  |>.findSome? (·.trimAscii.dropPrefix? "lean_exe GenerateSlides where")
  |>.isSome

def extractDeps (s: String) :=
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

def lakefile : System.FilePath := "lakefile.lean"
def GenerateSlides : System.FilePath := "GenerateSlides.lean"

def main : IO Unit := do
  if !(<- lakefile.pathExists) then
    throw <| IO.userError s!"{lakefile} not found"

  let lakefileContents <- IO.FS.readFile lakefile
  let libs := extractDeps lakefileContents

  if !(<- GenerateSlides.pathExists) then
     IO.FS.writeFile GenerateSlides <| generateSlidesLean libs

  if !(containsLeanExeDecl lakefileContents) then
     IO.FS.writeFile lakefile <|
        lakefileContents
        ++ "\n"
        ++ String.intercalate "\n" prelude
     let _ <- IO.Process.spawn {
        cmd := "lake",
        args := #["exec", "GenerateSlides"]
     }
