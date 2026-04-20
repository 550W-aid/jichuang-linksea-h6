# GitHub Collaboration Workflow

This repository uses one shared GitHub repository with separate local worktrees for
FPGA code collaboration.

## Local Workspaces

- `integration`: local integration branch for merging and verification.
- `person-1`: worktree for contributor 1, branch `dev/person-1`.
- `person-2`: worktree for contributor 2, branch `dev/person-2`.
- `person-3`: worktree for contributor 3, branch `dev/person-3`.

## Daily Contributor Flow

Run these commands from your own worktree:

```powershell
git pull --ff-only
git add fpga tools docs
git commit -m "feat: describe your fpga change"
git push
```

## Local Integration Flow

Run these commands from the `integration` worktree:

```powershell
git fetch origin
git merge --no-ff origin/dev/person-1
git merge --no-ff origin/dev/person-2
git merge --no-ff origin/dev/person-3
python tools/check_startup.py
python tools/run_camera_sims.py
git push origin integration
```

After the integrated result is verified, merge `integration` into `main` and push
`main`.
