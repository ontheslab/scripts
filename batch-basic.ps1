param (
    [string]$sourceDir,
    [string]$targetDir
)

function Show-Help {
    Write-Output "PowerShell Batch copy using TeraCopy (Max 100 items at a time)"
    Write-Output "Usage: .\batch.ps1 -sourceDir <SourceDirectory> -targetDir <TargetDirectory>"
    Write-Output "Example: .\batch.ps1 -sourceDir 'C:\Path\To\Source' -targetDir 'C:\Path\To\Target'"
}

# Check if source and target directories are provided
if (-not $sourceDir -or -not $targetDir) {
    Show-Help
    exit
}

Write-Output "Source Directory: $sourceDir"
Write-Output "Target Directory: $targetDir"

# Get a list of all files in the source directory and their sub-directories
$files = Get-ChildItem -Path $sourceDir -File -Recurse
Write-Output "Total files found: $($files.Count)"

# Group files by directory
$filesByDirectory = $files | Group-Object { $_.DirectoryName }

foreach ($directoryGroup in $filesByDirectory) {
    $directoryPath = $directoryGroup.Name
    if ($directoryPath.Length -gt $sourceDir.Length) {
        $relativePath = $directoryPath.Substring($sourceDir.Length).TrimStart('\').Replace('.', '')
    } else {
        $relativePath = ""
    }
    $targetDirectoryPath = Join-Path $targetDir $relativePath

    Write-Output "Processing directory: $directoryPath"
    Write-Output "Relative path: $relativePath"
    Write-Output "Target directory path: $targetDirectoryPath"

    # Create the target directory if it doesn't exist
    if (-not (Test-Path -Path $targetDirectoryPath)) {
        Write-Output "Creating target directory: $targetDirectoryPath"
        New-Item -Path $targetDirectoryPath -ItemType Directory | Out-Null
    }

    # Group files into batches of 100
    $fileGroups = @()
    $group = @()
    foreach ($file in $directoryGroup.Group) {
        $group += $file
        if ($group.Count -eq 100) {
            Write-Output "Processing batch of 100 files in directory $directoryPath."
            $fileGroups += ,$group
            $group = @()
        }
    }
    if ($group.Count -gt 0) {
        Write-Output "Processing final batch of $($group.Count) files in directory $directoryPath."
        $fileGroups += ,$group
    }

    # Copy each group of files using TeraCopy
    foreach ($group in $fileGroups) {
        if ($group.Count -eq 0) {
            Write-Output "Skipping empty batch."
            continue
        }

        $fileList = $group | ForEach-Object { $_.FullName }
        $fileListString = $fileList -join "`n"
        $tempFileList = [System.IO.Path]::GetTempFileName()

        # Ensure only non-empty lines are written to the temporary file
        $nonEmptyFileListString = $fileListString -replace "(`n)+", "`n"
        if ($nonEmptyFileListString -match "^\s*$") {
            Write-Output "Skipping batch with empty file list."
            continue
        }

        Set-Content -Path $tempFileList -Value $nonEmptyFileListString

        Write-Output "Temporary file list created at: $tempFileList"
        Write-Output "File list content:"
        Write-Output $nonEmptyFileListString

        Write-Output "Copying batch to $targetDirectoryPath using TeraCopy."
        # Use TeraCopy to copy the files
        $quotedTempFileList = "`"$tempFileList`""
        $quotedTargetDirectoryPath = "`"$targetDirectoryPath`""
        Write-Output "TeraCopy command: Copy *$quotedTempFileList $quotedTargetDirectoryPath /Overwrite"
        $process = Start-Process -FilePath "C:\Program Files\TeraCopy\TeraCopy.exe" -ArgumentList "Copy", "*$quotedTempFileList", $quotedTargetDirectoryPath, "/Overwrite" -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            Write-Output "TeraCopy failed with exit code $($process.ExitCode)."
        } else {
            Write-Output "Batch copied successfully."
        }

        # Clean up the temporary file
        Remove-Item -Path $tempFileList
    }
}

Write-Output "File copy operation completed."
