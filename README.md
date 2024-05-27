# StableDiffusionAutomation #
Automating Stable diffusion with PowerShell

## Check latest updates and tutorials [developerbastian.tech](https://developerbastian.tech/) ##

## File in this repository ##
- SD_Automate.ps1
	- Features:
		- Query a Stable Diffusion API 
		- Steer prompts from JSON file (your json objects need to have two properties: 'Picture Prompt' (The prompt to be used in addition to the local variable '$prompt') and 'Name' (The name of the resulting *.png file. The name will be extended if more than one file )
		- Automatic renaming of files for batch size > 1
		- uses PowerShell 
	- All links for models, LORAs etc used are in the header of this File
- SD_Start.ps1
	- Update and start a stable diffusion local install
- Minerals.json
	- >3k of minerals from [Kaggle](https://www.kaggle.com/datasets/vinven7/comprehensive-database-of-minerals/data)
	- extended the original data set by several descriptions inventing the properties of the minerals using a LLM
	- created prompts using a LLM to be usable here in image generation, retrieved from the made up properties

## Video ##


