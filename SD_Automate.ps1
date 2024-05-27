#region Variables

	# URL to your Stable Diffusion API
	[string]$apiUrl = "http://localhost:7860/sdapi/v1/txt2img"
	
	# The file with the prompt. It has a json array, with two fields mandatory to steer the image creation
	# 'Picture Prompt': The prompt to be used in addition to the local variable '$prompt' (see below)
	# 'Name': The name of the resulting *.png file. The name will be extended if more than one file is generated with a counter, e.g. Name01.png
	[string]$promptJsonFile = "D:\3D\Unreal_Projects\DataFileDemo\Plugins\BA_DataContent\Resources\Minerals.json"
	
	# path to store images to - will be created if not existing
	[string]$pathToStoreOutputImages = "d:\SD\out"
	
	# SD model used:
	# model by https://civitai.com/user/SG_161222
	# home page CivitAI: https://civitai.com/models/133005/juggernaut-xl
	# download https://bit.ly/juggernaut_xl
	# or download at HuggingFace: https://huggingface.co/RunDiffusion/Juggernaut-X-v10/blob/main/Juggernaut-X-RunDiffusion-NSFW.safetensors
	# copy into stable-diffusion-webui\models\Stable-diffusion
	# if you change the model, for the exact model name generate a picture in the web ui and find its name in the picture summary
	[string]$model = "Juggernaut-X-RunDiffusion-NSFW"
	
	#LORA used:
		# model by https://civitai.com/user/Lykon
		# download https://civitai.com/models/82098/add-more-details-detail-enhancer-tweaker-lora
		# copy into stable-diffusion-webui\models\lora
		# the lora influence should be quite small
	[string]$lora = "<lora:more_details:0.2>"
		
	# how many pictures per request should be created?
	[int]$batchSize = 1
	
	# main prompt
	[string]$generalPrompt = " (magic crystal) (white background:1.5) (subsurface scattering) (zoom:2) "
	
	[string]$negativePrompt = "(blurry) (out of focus) (depth of field:2) (shadow:2) (text)"
	
	# Seed - default is -1, so generating a random seed with each generation
	[int]$seed = 748221179
	
	# if an output file with the target name exists, this SD API request will be skipped
	[bool]$skipIfFileExists = $true
	
#endregion

#region Functions

	<#
	.SYNOPSIS
		function to send a query to the stable diffusion API.

	.DESCRIPTION
		This function sends a prompt to an image request API, retrieves the response, and processes any images found.

	.PARAMETER apiUrl
		The URL of the image request API.

	.PARAMETER requestBody
		A hashtable containing the request body, including the 'prompt' key.

	.PARAMETER outputPath
		The path where output images should be stored.

	.PARAMETER fileName
		The desired filename for the output images.

	.EXAMPLE
		Invoke-ImageRequest -apiUrl 'https://api.example.com/image' -requestBody @{ prompt = 'Generate an image' } -outputPath 'C:\Output' -fileName 'output.png'

	#>
	
	function Invoke-ImageRequest {
		[CmdletBinding()]
		param (
			[string]$apiUrl,
			[hashtable]$requestBody,
			[string]$outputPath,
			[string]$fileName
		)
		$fullFilePath = Join-Path -Path $outputPath -ChildPath $fileName
		if ((Test-Path -Path $fullFilePath) -and ($skipIfFileExists -eq $true)) {
			Write-Host "Warning: Skipping generation of '$fullFilePath' as this file exists and var 'skipIfFileExists = true'" -ForegroundColor DarkYellow
			return
		}
		try {
			# Send the request
			$sw = [System.Diagnostics.Stopwatch]::StartNew()
			$response = Invoke-RestMethod -Uri $apiUrl -Method Post -ContentType "application/json" -Body ($requestBody | ConvertTo-Json)
			# Report duration
			$sw.Stop()
			$elapsedSeconds = [math]::Round($sw.Elapsed.TotalSeconds, 2)
			Write-Host "Request duration: $elapsedSeconds seconds" -ForegroundColor Yellow
			# Check response
			if ($response -ne $null) {
				if ($response.images) {
					$imagesFromResponse = $response.images
					Process-Images -Images $imagesFromResponse -OutputPath $outputPath -FileName $fileName
					return $true
				} else {
					Write-Host "No images found in the response" -ForegroundColor Yellow					
				}
			} else {
				Write-Host "Response is invalid or empty" -ForegroundColor Red
			}
		} catch {
			$errorMessage = $_.Exception.Message
			Write-Host "Error: $errorMessage" -ForegroundColor Red
		}
		return $false
	}
	
	<#
	.SYNOPSIS
		Processes images from an API response and saves them to a specified path.

	.DESCRIPTION
		This function processes an array of images received from an API response. It combines them into a single file (if applicable) and saves them to the specified output path.

	.PARAMETER images
		An array of base64-encoded image strings as response from SD API.

	.PARAMETER outputPath
		The directory where the processed image(s) will be saved.

	.PARAMETER fileName
		The desired filename for the output image(s).

	.EXAMPLE
		Process-Images -images $imageArray -outputPath 'C:\Output' -fileName 'combined_image.png'

	#>
	
	function Process-Images {
		[CmdletBinding()]
		param (
			[array]$images,
			[string]$outputPath,
			[string]$fileName
		)

		try {
			Write-Host "Processing $($images.Count) images from response..." -ForegroundColor Yellow

			# Combine output path and file name
			$fullFilePath = Join-Path -Path $outputPath -ChildPath $fileName

			# Initialize variables
			$firstProcessed = $false
			$count = 0

			foreach ($image in $images) {
				# Iterate over the array of images
				$decodedBytes = [Convert]::FromBase64String($image)
				$modifiedFilePath = $fullFilePath

				# Add a counter to the filename after the first image has been processed
				if ($firstProcessed) {
					$formattedCount = '{0:D2}' -f $count
					$count++
					$modifiedFilePath = $fullFilePath

					$lastPeriodIndex = $fullFilePath.LastIndexOf('.')
					if ($lastPeriodIndex -ge 0) {
						$modifiedFilePath = $modifiedFilePath.Insert($lastPeriodIndex, $formattedCount)
					} else {
						# Handle the case when there's no period in the string
						Write-Host "No period found in the file path '$modifiedFilePath'." -ForegroundColor DarkYellow
					}
				}

				if (Test-Path -Path $modifiedFilePath) {
					Write-Host "Warning: Overwriting file '$modifiedFilePath'" -ForegroundColor DarkYellow
				}

				try {
					[IO.File]::WriteAllBytes($modifiedFilePath, $decodedBytes)
					Write-Host "Success: Saving new image '$modifiedFilePath'" -ForegroundColor Green
				} catch {
					Write-Host "Failure: Exception on writing file '$modifiedFilePath': $_" -ForegroundColor Red
				}

				$firstProcessed = $true
			}
		} catch {
			Write-Host "Error: $_" -ForegroundColor Red
		}
	}



	<#
	.SYNOPSIS
		Checks if the output directory exists and creates it if necessary.

	.DESCRIPTION
		This function verifies whether the specified output directory exists. If not, it creates the directory.

	.PARAMETER pathToStoreOutputImages
		The path to the output directory where images will be stored.

	.EXAMPLE
		Check-OutputPath -pathToStoreOutputImages 'C:\Output'

	#>

	function Check-OutputPath {
		[CmdletBinding()]
		param (
			[string]$outputPath
		)

		try {
			# Check if the output directory exists
			if (-not (Test-Path -PathType Container $outputPath)) {
				# Create the output directory
				try {
					New-Item -ItemType Directory -Path $outputPath | Out-Null
					Write-Host "Created output directory: $outputPath" -ForegroundColor Yellow
				} catch {
					$errorMessage = $_.Exception.Message
					Write-Host "Error while creating output directory '$outputPath': $errorMessage" -ForegroundColor Red
				}
			} else {
				Write-Host "Output directory already exists: $outputPath" -ForegroundColor Green
			}
		} catch {
			Write-Host "Error: $_" -ForegroundColor Red
		}
	}

	<#
	.SYNOPSIS
	Resizes a PNG image to the specified dimensions.

	.DESCRIPTION
	This function takes an input PNG image and resizes it to the desired width and height. The resized image is saved as a new PNG file.

	.PARAMETER SourceImagePath
	The path to the input PNG image.

	.PARAMETER NewWidth
	The desired width of the resized image in pixels.

	.PARAMETER NewHeight
	The desired height of the resized image in pixels.

	.EXAMPLE
	Resize-Image -SourceImagePath "C:\path\to\input.png" -TargetImagePath "C:\path\to\input__resized.png"  -NewWidth 800 -NewHeight 600
	#>
	
	function Resize-Image {
		[CmdletBinding()]
		param (
			[Parameter(Mandatory=$true, Position=0)]
			[string]$SourceImagePath,
			
			[Parameter(Mandatory=$true, Position=1)]
			[string]$TargetImagePath,

			[Parameter(Mandatory=$true)]
			[int]$NewWidth,

			[Parameter(Mandatory=$true)]
			[int]$NewHeight
		)

		try {
			# Load the image
			$image = [System.Drawing.Image]::FromFile($SourceImagePath)

			# Create a new bitmap with the same pixel format as the source image
			$resizedImage = New-Object System.Drawing.Bitmap $NewWidth, $NewHeight, $image.PixelFormat

			# Create a graphics object for drawing
			$graphics = [System.Drawing.Graphics]::FromImage($resizedImage)
			$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

			# Draw the original image onto the resized bitmap
			$graphics.DrawImage($image, 0, 0, $NewWidth, $NewHeight)

			# Save resized image
			$resizedImage.Save($TargetImagePath + ".png", [System.Drawing.Imaging.ImageFormat]::Png)

			Write-Host "Image '$SourceImagePath' resized and saved to '$TargetImagePath'" -ForegroundColor Green
		}
		catch {
			Write-Host "Error resizing the image '$SourceImagePath': $_" -ForegroundColor Red
		}
		finally {
			# Clean up
			$image.Dispose()
			$resizedImage.Dispose()
			$graphics.Dispose()
		}
	}

	<#
	.SYNOPSIS
	Retrieves specific fields from a JSON file and returns them in a hash table.

	.DESCRIPTION
	This function reads a JSON file, extracts the specified 'name' and 'Picture Prompt' fields from each object, and returns them in a hash table.

	.PARAMETER JsonFilePath
	Specifies the path to the JSON file.

	.EXAMPLE
	PS> Get-JsonFieldsFromObject -JsonFilePath "C:\path\to\your\jsonfile.json"
	Returns a hash table containing the extracted fields.

	.NOTES
	File format: The JSON file should contain an array of json objects, each with 'name' and 'Picture Prompt' properties.
	#>
	function Get-JsonFieldsFromObject {
		param (
			[string]$JsonFilePath
		)
		# Initialize an empty hash table
		$result = @{}
		# Check if the file exists
		if (-not (Test-Path -Path $JsonFilePath -PathType Leaf)) {
			Write-Host "Error: The specified JSON file does not exist." -ForegroundColor Red	
			return $result
		}
		try {
			# Read the JSON content from the file
			$jsonContent = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json

			# Iterate over the array of JSON objects
			foreach ($item in $jsonContent) {
				# Extract the 'name' and 'Picture Prompt' fields
				$name = $item.Name
				$picturePrompt = $item.'Picture Prompt'
				if (-not ([string]::IsNullOrEmpty($name)) -and -not ([string]::IsNullOrEmpty($picturePrompt))) {
					$result[$name] = $picturePrompt
				} else {
					Write-Host "Skipping the following json object as one or more parameter are empty: `n `t Name: '$name'`n `t Picture Prompt: '$picturePrompt'`n" -ForegroundColor Red	
				}
				
			}
		} catch {
			Write-Host "Error loading Json file '$promptJsonFile': $_" -ForegroundColor Red	
		}
		
		# Report and return the hash table
		Write-Host "Loaded" $result.Count "names and regarding prompts from Json file '$promptJsonFile'" -ForegroundColor DarkYellow
		return $result
	}

#endregion

#region Main
	
	# check if output path exists - if not, create it
	Check-OutputPath -outputPath $pathToStoreOutputImages
	
	# load prompt data
	$hashTable = Get-JsonFieldsFromObject -JsonFilePath $promptJsonFile
	[int]$hashTableCounter = 0
	
	# iterate over hash table
	foreach ($entry in $hashTable.GetEnumerator()) {
		$hashTableCounter++
		
		# put prompt together
		[string]$composedPrompt = "(" + $entry.Value + " " + $generalPrompt + " " + $lora

		# request body send to Stable Diffusion 
		$requestBody = @{
			prompt = $composedPrompt
			negative_prompt = $negativePrompt
			model = $model
			seed = $seed
			sampler_name = "DPM++ SDE"
			scheduler = "Karras"
			batch_size = $batchSize
			n_iter = 1
			steps = 17
			denoising_strength = 0.7
			hr_scale = 2
			cfg_scale = 5
			width = 1024
			height = 1024
			restore_faces = $false
			tiling = $false
			save_images = $false
		}		
		# define file name
		$fileName = $($entry.Name) + ".png"
		
		# report progress
		Write-Host "`nSending API request $hashTableCounter /"$hashTable.Count -ForegroundColor Green
		Write-Host "Prompt for '"$entry.Name"':"  -ForegroundColor Cyan
		Write-Host "'"$composedPrompt"'"  -ForegroundColor Cyan
		
		# query API
		$result = Invoke-ImageRequest -apiUrl $apiUrl -requestBody $requestBody -outputPath $pathToStoreOutputImages -fileName $fileName
		
		# if something goes wrong, exit this routine as API seems to be not working
		if ($result -eq $false) {
			Write-Host "Exiting routine as error occured during API call" -ForegroundColor Red
			exit
		}
	}
		
#endregion
