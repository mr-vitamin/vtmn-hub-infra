"""Offline tests: all Proxmox commands are substituted; no server access."""
import json, os, pathlib, subprocess, sys, tempfile, unittest
SOURCE=pathlib.Path(os.environ["WP_SOURCE"])
WORK=pathlib.Path(os.environ["WP_TEST_WORK"])
def shpath(p):
    s=str(p).replace("\\","/")
    return "/"+s[0].lower()+s[2:] if len(s)>1 and s[1]==":" else s
MOCK=r'''
import json,os,pathlib,sys
name=pathlib.Path(sys.argv[1]).name
a=sys.argv[2:]; root=pathlib.Path(os.environ["MOCK_ROOT"]); s=os.environ["SCENARIO"]
with (root/"calls").open("a") as f: f.write(json.dumps([name]+a)+"\n")
def out(v): print(json.dumps(v))
def fail(): sys.exit(1)
ids=list(range(101,109))
job=dict(id="legacy",all=0,vmid="101,102,103,104,105,106,107,108",schedule="02:00",
 storage="backup-tank",mode="snapshot",compress="zstd",enabled=1)
job["prune-backups"]={"keep-daily":7,"keep-weekly":4}
if name=="id": print("1000" if s=="nonroot" else "0")
elif name=="flock":
 if s=="locked": fail()
elif name=="sleep": pass
elif name=="ip":
 if s=="bridge-fail": fail()
elif name=="pvesm":
 if s=="template-fail": fail()
 print((root/"template").as_posix())
elif name=="pct":
 if a[0]=="create" and s=="create-fail" and a[1]=="103": fail()
 elif a[0]=="start" and s=="start-fail": fail()
 elif a[0]=="exec":
  if s=="no-ip": fail()
  out([{"addr_info":[{"family":"inet","scope":"global","local":"192.0.2.108"}]}])
elif name=="pvesh":
 if a[0]=="create":
  if s=="backup-fail": fail()
  (root/"created").write_text("yes")
 elif a[1]=="/cluster/resources":
  if s=="query-fail": fail()
  if s=="bad-json": print("broken")
  elif os.environ["WHICH"]=="create": out([{"vmid":104,"type":"qemu"}] if s=="collision" else [])
  else: out([{"vmid":i,"type":"lxc"} for i in ids if not(s=="missing-guest" and i==107)])
 elif a[1].startswith("/storage/"):
  if s=="storage-fail": fail()
  out({"type":"zfspool","content":"rootdir"} if a[1].endswith("/tank") else {"content":"backup"})
 elif a[1]=="/cluster/backup":
  if s=="jobs-fail": fail()
  if s=="jobs-bad": out({})
  elif (root/"created").exists():
   job["id"]="vtmn-hub-daily"; out([] if s=="readback-fail" else [job])
  elif s=="equivalent": out([job])
  elif s=="conflict":
   job["schedule"]="03:00"; out([job])
  elif s=="duplicate": out([job,dict(job,id="other")])
  elif s=="disabled":
   job["enabled"]=0; out([job])
  elif s=="all-job": out([{"id":"all","all":1}])
  elif s=="unknown-job": out([{"id":"pool","pool":"other"}])
  else: out([])
 else: fail()
else: fail()
'''
class Safety(unittest.TestCase):
 def run_script(self,which,s,answer="DNS-READY\n",extra=None):
  case=pathlib.Path(tempfile.mkdtemp(prefix="case-",dir=WORK))
  (case/"template").write_text("dummy"); (case/"mock.py").write_text(MOCK)
  bins=case/"bin"; bins.mkdir()
  for name in ("pct","pvesh","pvesm","ip","id","flock","sleep"):
   p=bins/name; p.write_text('#!/bin/bash\nexec "$WP_PYTHON" "$MOCK_ROOT/mock.py" "$0" "$@"\n',newline="\n"); p.chmod(0o755)
  p=bins/"python3"; p.write_text('#!/bin/bash\nfile=$1; shift\nif command -v cygpath >/dev/null; then file=$(cygpath -w "$file"); fi\nexec "$WP_PYTHON" "$file" "$@"\n',newline="\n"); p.chmod(0o755)
  env={k:v for k,v in os.environ.items() if k in ("SystemRoot","WINDIR","TEMP","TMP","COMSPEC")}
  env.update(PATH=shpath(bins)+":/usr/bin:/bin",MSYS2_ARG_CONV_EXCL="*",WP_PYTHON=pathlib.Path(sys.executable).as_posix(),
   WP_MOCK_BIN=shpath(bins),MOCK_ROOT=case.as_posix(),SCENARIO=s,WHICH=which,DNS_ATTEMPTS="2",DNS_INTERVAL="1")
  if extra: env.update(extra)
  script="create-containers.sh" if which=="create" else "backup-job.sh"
  r=subprocess.run([os.environ.get("WP_BASH","/bin/bash"),"--noprofile","--norc","-c",'export PATH="$WP_MOCK_BIN:/usr/bin:/bin"; for cmd in pct pvesh pvesm ip id flock sleep python3; do [[ $(command -v "$cmd") == "$WP_MOCK_BIN/$cmd" ]] || exit 99; done; target=$1; shift; source "$target"','test',shpath(SOURCE/"proxmox"/script)],
   input=answer.encode(),capture_output=True,env=env,cwd=case,timeout=25)
  r.stdout=r.stdout.decode(); r.stderr=r.stderr.decode()
  c=[json.loads(x) for x in (case/"calls").read_text().splitlines()] if (case/"calls").exists() else []
  return r,c
 def writes(self,c): return [x for x in c if x[0] in ("pct","pvesh") and x[1] in ("create","start")]
 def test_creation_stops_at_first_failure(self):
  r,c=self.run_script("create","create-fail")
  self.assertNotEqual(r.returncode,0,r.stdout)
  self.assertTrue(any(x[:3]==["pct","create","103"] for x in c),c)
  self.assertFalse(any(x[:3]==["pct","create","104"] for x in c),c)
  self.assertNotIn("All containers created",r.stdout)
 def test_backup_failure_never_reports_success(self):
  r,c=self.run_script("backup","backup-fail")
  self.assertTrue(any(x[:3]==["pvesh","create","/cluster/backup"] for x in c),c)
  self.assertNotEqual(r.returncode,0,r.stdout); self.assertNotIn("Backup job created",r.stdout)
 def test_creation_preflight(self):
  for s in ("collision","query-fail","bad-json","bridge-fail","storage-fail","template-fail","nonroot","locked"):
   with self.subTest(s=s):
    r,c=self.run_script("create",s); self.assertNotEqual(r.returncode,0,r.stdout); self.assertEqual(self.writes(c),[])
 def test_bounded_readiness(self):
  r,c=self.run_script("create","no-ip"); self.assertNotEqual(r.returncode,0)
  self.assertFalse(any(x[:3]==["pct","create","101"] for x in c))
  self.assertLessEqual(sum(x[:3]==["pct","exec","108"] for x in c),2)
 def test_start_and_confirmation_failure(self):
  for s,answer in (("start-fail","DNS-READY\n"),("ok",""),("ok","\n")):
   with self.subTest(s=s,answer=answer):
    r,c=self.run_script("create",s,answer); self.assertNotEqual(r.returncode,0)
    self.assertFalse(any(x[:3]==["pct","create","101"] for x in c))
 def test_bad_wait_values(self):
  for v in ("0","-1","abc","999999","01"):
   with self.subTest(v=v):
    r,c=self.run_script("create","ok",extra={"DNS_ATTEMPTS":v})
    self.assertNotEqual(r.returncode,0); self.assertEqual(self.writes(c),[])
 def test_guest_layout(self):
  r,c=self.run_script("create","ok"); self.assertEqual(r.returncode,0,r.stderr)
  creates=[x for x in c if x[:2]==["pct","create"]]
  self.assertEqual([x[2] for x in creates],["108","101","102","103","104","105","106","107"])
  for x in creates:
   self.assertEqual(x[x.index("--unprivileged")+1],"1")
   self.assertEqual(x[x.index("--net0")+1],"name=eth0,bridge=vmbr0,ip=dhcp")
  self.assertEqual([x for x in c if x[:2]==["pct","start"]],[["pct","start","108"]])
 def test_equivalent_noop(self):
  r,c=self.run_script("backup","equivalent"); self.assertEqual(r.returncode,0,r.stderr); self.assertEqual(self.writes(c),[])
 def test_job_conflicts(self):
  for s in ("conflict","duplicate","disabled","all-job","unknown-job","jobs-fail","jobs-bad","missing-guest","storage-fail"):
   with self.subTest(s=s):
    r,c=self.run_script("backup",s); self.assertNotEqual(r.returncode,0,r.stdout); self.assertEqual(self.writes(c),[])
 def test_backup_success(self):
  r,c=self.run_script("backup","ok"); self.assertEqual(r.returncode,0,r.stderr)
  self.assertEqual(len(self.writes(c)),1); self.assertIn("vtmn-hub-daily",self.writes(c)[0])
  self.assertIn("keep-daily=7,keep-weekly=4",self.writes(c)[0])
 def test_readback_failure(self):
  r,c=self.run_script("backup","readback-fail"); self.assertNotEqual(r.returncode,0)
  self.assertNotIn("Backup job created",r.stdout)

class JSONChecks(unittest.TestCase):
 def check(self,mode,value,ok,expected=None):
  r=subprocess.run([sys.executable,str(SOURCE/"proxmox/script-safety.py"),mode],
                   input=json.dumps(value),text=True,capture_output=True)
  self.assertEqual(r.returncode==0,ok,(mode,r.stdout,r.stderr))
  if expected is not None: self.assertEqual(r.stdout.strip(),expected)
 def test_malformed_inventory(self):
  for v in ({},[{"vmid":"104","type":"lxc"}],[{"vmid":104,"type":"unknown"}],
            [{"vmid":104,"type":"lxc"},{"vmid":104,"type":"lxc"}]):
   self.check("new-guests",v,False)
 def test_storage_validation(self):
  for v in ({},{"content":"backup","disable":1},{"content":"backup","disable":"broken"}):
   self.check("backup-storage",v,False)
  self.check("root-storage",{"content":"rootdir","type":"dir"},False)
  self.check("root-storage",{"content":"rootdir,images","type":"zfspool"},True)
 def test_dns_validation(self):
  for ip in ("","127.0.0.1","169.254.1.1","224.0.0.1","0.0.0.0","255.255.255.255","300.1.1.1","::1"):
   self.check("dns-address",[{"addr_info":[{"family":"inet","scope":"global","local":ip}]}],False)
  self.check("dns-address",[{"addr_info":[]}],False)
  self.check("dns-address",[{"addr_info":[{"family":"inet","scope":"global","local":x} for x in ("10.0.0.1","10.0.0.2")]}],False)
  self.check("dns-address",[{"addr_info":[{"family":"inet","scope":"global","local":"10.0.0.108"}]}],True,"10.0.0.108")
 def test_equivalence_options(self):
  j={"id":"old","all":"0","vmid":"108 107 106 105 104 103 102 101","schedule":"02:00",
     "storage":"backup-tank","mode":"snapshot","compress":"zstd","enabled":"1",
     "prune-backups":"keep-weekly=4,keep-daily=7"}
  self.check("jobs",[j],True,"exists")
  for key,v in (("prune-backups","keep-daily=7,keep-weekly=4,keep-last=1"),("node","other"),
                ("exclude","101"),("enabled",0),("schedule","daily")):
   self.check("jobs",[dict(j,**{key:v})],False)
 def test_disjoint_and_ambiguous_jobs(self):
  self.check("jobs",[{"id":"other","all":0,"vmid":"999"}],True,"create")
  self.check("jobs",[{"id":"vtmn-hub-daily","all":0,"vmid":"999"}],False)
  for v in ({},[{}],[{"id":"unknown"}],[{"id":"bad","vmid":"101:108"}]):
   self.check("jobs",v,False)

if __name__=="__main__":
 WORK.mkdir(parents=True,exist_ok=True); unittest.main(verbosity=2)

