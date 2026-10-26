#!/usr/bin/env python3
"""Опрос статуса GitHub Actions (CI + Release) для последнего коммита/тега."""
import json, os, subprocess, sys, time

def gh_api(path):
    url = subprocess.check_output(['git', 'remote', 'get-url', 'origin'], text=True).strip()
    cred = url.split('://')[1].split('@')[0]
    token = cred.split(':')[1] if ':' in cred else cred
    import urllib.request
    req = urllib.request.Request('https://api.github.com' + path,
        headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json'})
    return json.load(urllib.request.urlopen(req))

def main():
    watch_sha = None
    for _ in range(60):
        runs = gh_api('/repos/RVMXL/SmartFridge-Chef/actions/runs?per_page=6')
        rows = [(r['name'], r['head_sha'][:7], r['status'], r['conclusion'], r['html_url']) for r in runs['workflow_runs']]
        os.system('clear' if os.name == 'posix' else 'cls')
        print(f"=== {time.strftime('%H:%M:%S')} ===")
        for r in rows:
            print(f"{r[0]:<12} {r[1]} {r[2]:<12} {r[3]}")
        if watch_sha is None and rows:
            watch_sha = rows[0][1]
        done = all(r[2] == 'completed' for r in rows if r[1] == watch_sha)
        if watch_sha and done:
            fails = [r for r in rows if r[1] == watch_sha and r[3] != 'success']
            print('RESULT:', 'FAIL: ' + str(fails) if fails else 'ALL SUCCESS')
            sys.exit(1 if fails else 0)
        time.sleep(30)

if __name__ == '__main__':
    main()
