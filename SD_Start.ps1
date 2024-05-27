# path to Stable Diffusion
$path = "D:\stable-diffusion-webui\"

# set up environment
$file = "webui.py"
$Env:COMMANDLINE_ARGS = "--api"
$Env:CUDA_VISIBLE_DEVICES = "0"
Set-Location -Path $path

# update SD - 'git' needs to be in path
Write-Host "Retrieving latest SD commit..." -ForegroundColor DarkYellow
$latest_run = (Invoke-RestMethod "https://api.github.com/repos/AUTOMATIC1111/stable-diffusion-webui/actions/workflows/40444318/runs").workflow_runs[0]

if ($latest_run.status -eq "completed" -and $latest_run.conclusion -eq "success") {
	Write-Host "Updating local repo..."
	git fetch
	git pull
} else {
	Write-Host "Latest commit is NOT stable, skipping..." -ForegroundColor DarkRed
}

# start SD
.\venv\Scripts\activate
python $file

