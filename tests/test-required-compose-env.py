"""Compose configuration-only checks with public dummy inputs; never starts/pulls images.
Usage: python test-required-compose-env.py CANDIDATE_ROOT BASELINE_ROOT FIXTURE_ROOT
"""
import json,os,pathlib,re,subprocess,sys,tempfile,unittest
SOURCE,BASELINE,WORK=map(lambda x:pathlib.Path(x).resolve(),sys.argv[1:4])
sys.argv=[sys.argv[0],*sys.argv[4:]]
REQUIRED={
 "authentik":("AUTHENTIK_SECRET_KEY","AUTHENTIK_DB_PASSWORD"),
 "wikijs":("WIKIJS_DB_PASSWORD",),
 "snipeit":("SNIPEIT_APP_KEY","SNIPEIT_DB_PASSWORD","SNIPEIT_DB_ROOT_PASSWORD"),
 "nextcloud":("NEXTCLOUD_DB_PASSWORD","NEXTCLOUD_DB_ROOT_PASSWORD")}
def fixture_env():
 allowed={"PATH","SYSTEMROOT","WINDIR","TEMP","TMP","HOME","USERPROFILE","APPDATA",
          "LOCALAPPDATA","PROGRAMFILES","PROGRAMDATA","COMSPEC","PATHEXT"}
 env={k:v for k,v in os.environ.items() if k.upper() in allowed}
 env["COMPOSE_DISABLE_ENV_FILE"]="1"
 return env
def dummy(var):
 return "base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" if var=="SNIPEIT_APP_KEY" else "offline-only-$-quote'#:value-"+var
class RequiredInputs(unittest.TestCase):
 def setUp(self):
  self.case=pathlib.Path(tempfile.mkdtemp(prefix="env-check-",dir=WORK))
  (self.case/"empty.env").write_text("",encoding="utf-8")
  (self.case/".env").write_text("\n".join(v+"=UNEXPECTED_DOT_ENV_VALUE" for vs in REQUIRED.values() for v in vs)+"\n",encoding="utf-8")
 def render(self,root,stack,values,quiet=False):
  env=fixture_env();env.update(values)
  command=["docker","compose","--env-file",str(self.case/"empty.env"),"--project-directory",str(self.case),
           "-p","wp11-offline","-f",str(root/"services"/stack/"docker-compose.yml"),"config"]
  command+=["--quiet"] if quiet else ["--format","json","--no-env-resolution"]
  return subprocess.run(command,env=env,cwd=self.case,capture_output=True,text=True,timeout=30)
 def values(self,stack):return {v:dummy(v) for v in REQUIRED[stack]}
 def test_missing_each_required_value_is_rejected(self):
  for stack,variables in REQUIRED.items():
   for var in variables:
    with self.subTest(stack=stack,var=var):
     values=self.values(stack);del values[var]
     r=self.render(SOURCE,stack,values)
     self.assertNotEqual(r.returncode,0,"missing variable accepted: "+var)
     self.assertIn(var,r.stderr,"failure must identify variable, not unrelated parse error")
     self.assertEqual(r.stdout.strip(),"","failure must not emit a resolved model")
 def test_empty_each_required_value_is_rejected(self):
  for stack,variables in REQUIRED.items():
   for var in variables:
    with self.subTest(stack=stack,var=var):
     values=self.values(stack);values[var]=""
     r=self.render(SOURCE,stack,values)
     self.assertNotEqual(r.returncode,0,"empty variable accepted: "+var)
     self.assertIn(var,r.stderr)
     self.assertEqual(r.stdout.strip(),"")
 def test_dummy_models_match_baseline_and_preserve_literals(self):
  for stack in REQUIRED:
   with self.subTest(stack=stack):
    values=self.values(stack)
    a=self.render(BASELINE,stack,values);b=self.render(SOURCE,stack,values)
    self.assertEqual(a.returncode,0,"baseline valid dummy model failed")
    self.assertEqual(b.returncode,0,"candidate valid dummy model failed")
    self.assertEqual(json.loads(a.stdout),json.loads(b.stdout),"nonempty configuration behavior changed")
    environments=[s.get("environment",{}) for s in json.loads(b.stdout)["services"].values()]
    for value in values.values():self.assertTrue(any(value.replace("$", "$$") in e.values() for e in environments),"literal dummy input was transformed")
    quiet=self.render(SOURCE,stack,values,quiet=True)
    self.assertEqual(quiet.returncode,0);self.assertEqual(quiet.stdout.strip(),"")
 def test_guard_is_not_a_format_or_strength_validator(self):
  values=self.values("snipeit");values["SNIPEIT_APP_KEY"]=" "
  r=self.render(SOURCE,"snipeit",values,quiet=True)
  self.assertEqual(r.returncode,0,"nonempty guard was misrepresented as format validation")
if __name__=="__main__":
 WORK.mkdir(parents=True,exist_ok=True);unittest.main(verbosity=2)
