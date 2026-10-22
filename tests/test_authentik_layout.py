"""Static IAM proposal checks; never contacts Docker Engine or Authentik.

Uses installed Docker Compose only as an offline YAML-to-JSON parser.
Custom Authentik tags are NOT evaluated or schema-validated.
Usage: python tests/test_authentik_layout.py REPOSITORY_ROOT
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(sys.argv[1]).resolve()
sys.argv = [sys.argv[0], *sys.argv[2:]]
SERVICE = ROOT / "services" / "authentik"

def compose_environment():
    # Keep process-launch essentials, not inherited application/Compose controls.
    allowed = {"PATH", "SYSTEMROOT", "WINDIR", "TEMP", "TMP", "HOME", "USERPROFILE",
               "APPDATA", "LOCALAPPDATA", "PROGRAMFILES", "PROGRAMDATA", "COMSPEC", "PATHEXT"}
    env = {key: value for key, value in os.environ.items() if key.upper() in allowed}
    env["COMPOSE_DISABLE_ENV_FILE"] = "1"
    return env

def parse_yaml(text):
    wrapped = "x-iam:\n" + "".join("  " + line + "\n" for line in text.splitlines())
    wrapped += "services:\n  parser-only:\n    image: scratch\n"
    # All scratch files stay below the supplied review root.
    with tempfile.TemporaryDirectory(prefix=".iam-offline-", dir=ROOT) as scratch:
        empty_env = Path(scratch) / "empty.env"
        empty_env.write_text("", encoding="utf-8")
        result = subprocess.run(
            ["docker", "compose", "--env-file", str(empty_env), "--project-directory", str(ROOT),
             "-p", "iam-offline", "-f", "-", "config",
             "--format", "json", "--no-interpolate", "--no-env-resolution"],
            input=wrapped, text=True, capture_output=True, check=True,
            cwd=scratch, env=compose_environment())
    return json.loads(result.stdout)["x-iam"]

class IdentityProposalTests(unittest.TestCase):
    def reviewed_sources(self):
        return list((SERVICE / "blueprints").glob("*.yaml")) + list((SERVICE / "candidates").glob("*.yaml.example"))

    def test_no_competing_application_or_outpost_writers(self):
        owners = set()
        for path in self.reviewed_sources():
            data = parse_yaml(path.read_text())
            for entry in data["entries"]:
                if entry["model"] not in ("authentik_core.application", "authentik_outposts.outpost"):
                    continue
                key = (entry["model"], json.dumps(entry["identifiers"], sort_keys=True))
                self.assertNotIn(key, owners, "competing application/outpost assignment")
                owners.add(key)

    def test_no_literal_oidc_secret_in_reviewed_sources(self):
        for path in self.reviewed_sources():
            data = parse_yaml(path.read_text())
            for entry in data["entries"]:
                secret = entry.get("attrs", {}).get("client_secret", "")
                self.assertFalse(str(secret).startswith("${"), "literal client secret placeholder")

    def test_no_ungated_project_yaml_in_discovery_tree(self):
        # Catch accidentally mounting or promoting historical/conflicting states.
        compose = parse_yaml((SERVICE / "docker-compose.yml").read_text())
        for name in ("server", "worker"):
            mounts = compose["services"][name]["volumes"]
            self.assertIn("./blueprints/local:/blueprints/local", mounts)
            self.assertFalse(any(v.startswith("./blueprints:") for v in mounts))
        self.assertTrue((SERVICE / "blueprints" / "local" / "README.md").is_file())
        self.assertEqual(list((SERVICE / "blueprints").rglob("*.yaml")), [])
        self.assertEqual(list((SERVICE / "blueprints").rglob("*.yml")), [])

    def test_single_forward_auth_owner_has_complete_self_contained_references(self):
        data = parse_yaml((SERVICE / "candidates" / "forward-auth.yaml.example").read_text())
        entries = data["entries"]
        providers = [e for e in entries if e["model"] == "authentik_providers_proxy.proxyprovider"]
        apps = [e for e in entries if e["model"] == "authentik_core.application"]
        outposts = [e for e in entries if e["model"] == "authentik_outposts.outpost"]
        self.assertEqual(len(providers), 3)
        self.assertEqual({e["identifiers"]["slug"] for e in apps}, {"docs", "snipeit", "homepage"})
        ids = {e["id"] for e in providers}
        self.assertEqual(len(ids), 3)
        self.assertEqual(len(outposts), 1)
        self.assertEqual(set(outposts[0]["attrs"]["providers"]), ids)
        for app in apps:
            self.assertIn(app["attrs"]["provider"], ids)
        self.assertFalse(any("oauth2" in e["model"] for e in entries))

    def test_secret_example_is_gated_and_wired_to_both_executing_processes(self):
        secret_file = SERVICE / "candidates" / "nextcloud-sso.yaml.example"
        raw = secret_file.read_text()
        data = parse_yaml(raw)
        providers = [e for e in data["entries"] if "oauth2provider" in e["model"]]
        self.assertEqual(len(providers), 1)
        self.assertEqual(providers[0]["attrs"]["client_id"], "nextcloud-vtmn")
        self.assertIn("client_secret: !Env NEXTCLOUD_OIDC_CLIENT_SECRET", raw)
        self.assertNotIn("client_secret: ${", raw)
        overlay = parse_yaml((SERVICE / "candidates" / "compose-secret-injection.yml.example").read_text())
        for name in ("server", "worker"):
            value = overlay["services"][name]["environment"]["NEXTCLOUD_OIDC_CLIENT_SECRET"]
            self.assertTrue(value.startswith("${NEXTCLOUD_OIDC_CLIENT_SECRET:?"))
        self.assertFalse(secret_file.is_relative_to(SERVICE / "blueprints"))

    def test_candidate_objects_have_no_competing_writers_or_invented_policies(self):
        objects = set()
        candidates = list((SERVICE / "candidates").glob("*.yaml.example"))
        self.assertEqual(len(candidates), 3)
        for path in candidates:
            data = parse_yaml(path.read_text())
            self.assertEqual(data["metadata"]["labels"]["blueprints.goauthentik.io/instantiate"], "false")
            for entry in data["entries"]:
                key = (entry["model"], json.dumps(entry["identifiers"], sort_keys=True))
                self.assertNotIn(key, objects)
                objects.add(key)
                self.assertNotIn("policybinding", entry["model"])
                self.assertNotIn("authenticator", entry["model"])

    def test_explicit_overlay_rejects_missing_secret_and_wires_dummy_value(self):
        # Test .env isolation with dummy trap data, never read actual service .env.
        with tempfile.TemporaryDirectory(prefix=".iam-offline-", dir=ROOT) as scratch:
            project = Path(scratch)
            (project / ".env").write_text(
                "NEXTCLOUD_OIDC_CLIENT_SECRET=must-not-be-loaded\n", encoding="utf-8")
            empty_env = project / "empty.env"
            empty_env.write_text("", encoding="utf-8")
            command = ["docker", "compose", "--env-file", str(empty_env),
                       "-p", "iam-offline", "--project-directory", str(project),
                       "-f", str(SERVICE / "docker-compose.yml"),
                       "-f", str(SERVICE / "candidates" / "compose-secret-injection.yml.example"),
                       "config", "--format", "json", "--no-env-resolution"]
            env = compose_environment()
            env.update(AUTHENTIK_SECRET_KEY="offline-test-only", AUTHENTIK_DB_PASSWORD="offline-test-only")
            missing = subprocess.run(command, env=env, capture_output=True, text=True, cwd=scratch)
            self.assertNotEqual(missing.returncode, 0)
            self.assertIn("NEXTCLOUD_OIDC_CLIENT_SECRET", missing.stderr)
            env["NEXTCLOUD_OIDC_CLIENT_SECRET"] = "offline-dummy-not-a-production-secret"
            supplied = subprocess.run(command, env=env, capture_output=True, text=True, cwd=scratch)
            self.assertEqual(supplied.returncode, 0, "offline Compose model rejected")
            config = json.loads(supplied.stdout)
            for name in ("server", "worker"):
                self.assertEqual(config["services"][name]["environment"]["NEXTCLOUD_OIDC_CLIENT_SECRET"],
                                 "offline-dummy-not-a-production-secret")

    def test_all_six_history_files_retained_outside_discovery(self):
        expected = {
            "forward-auth-setup.yaml", "homepage-forward-auth.yaml",
            "hub-branding.yaml", "nextcloud-sso.yaml",
            "revert-docs-forward-auth.yaml", "wikijs-oidc.yaml"}
        self.assertEqual({p.name for p in (SERVICE / "history").glob("*.yaml")}, expected)
        self.assertFalse((SERVICE / "history").is_relative_to(SERVICE / "blueprints"))

if __name__ == "__main__":
    unittest.main(verbosity=2)
