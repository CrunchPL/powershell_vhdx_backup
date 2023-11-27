# Send a system notification about the start of the backup process
$notificationTitleStart = "Starting the backup process"
$notificationMessageStart = "Please wait..."
New-BurntToastNotification -Text $notificationTitleStart -AppLogo $PSScriptRoot -Sound "Notification.Default" -SnoozeAndDismiss

# Check if the C: drive is connected
if ($physicalDisk -eq $null) {
    Write-Output "The C: drive is not connected."
    exit
}

# Configure the physical disk (where the C: drive is located)
$physicalDisk = (Get-Partition -DriveLetter 'C').DiskNumber

# Configure the network share path
$smbServer = "server"
$networkPath = "\\$smbServe\share_name"

# Default authentication credentials (to be replaced)
$username = "your_username"
$password = "your_password"
$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePassword

# Check SMB server connectivity
try {
    Test-Connection -ComputerName $smbServe -Count 2 -ErrorAction Stop
} catch {
    Write-Output "Unable to connect to the SMB server."
    exit
}

# Get the partitions of the physical disk
$physicalDiskPartitions = Get-Partition -DiskNumber $physicalDisk | Sort-Object DiskNumber, PartitionNumber

# Create a file name based on the current date
$currentDate = Get-Date -Format "dd-MM-yyyy"
$fileName = "$currentDate.vhdx"

# Create the full path for the VHDX file
$destinationPath = Join-Path $networkPath $fileName

# Create a new VHDX file with partitions
New-VHD -Path $destinationPath -SizeBytes 50GB -Dynamic
Initialize-Disk -Number $destinationPath -PartitionStyle GPT
$physicalDiskPartitions | ForEach-Object {
    $partition = $_
    $volume = Get-Volume -Partition $partition
    $driveLetter = $volume.DriveLetter
    $partitionPath = Join-Path $destinationPath $driveLetter
    Resize-Partition -Partition $partition -Size ($partition.Size - 1MB) # Set partition size (optional)
    New-Partition -AssignDriveLetter -UseMaximumSize -DiskNumber $destinationPath -Size $partition.Size
    Copy-Item "$driveLetter\*" -Destination "$partitionPath" -Recurse -Force
}

# Compress the VHDX file
Compress-Archive -Path $destinationPath -DestinationPath "$destinationPath.zip" -Force

# Get the list of ZIP files in the network folder and remove the oldest if there are more than 4 files
$zipFiles = Get-ChildItem -Path $networkPath -Filter *.zip | Sort-Object LastWriteTime -Descending
if ($zipFiles.Count -gt 4) {
    $oldestFile = $zipFiles[-1]
    Remove-Item $oldestFile.FullName -Force
}

# Send a system notification about the successful completion of the backup process
$notificationTitleEnd = "Backup process completed successfully"
$notificationMessageEnd = "$computerName-$currentDate"
New-BurntToastNotification -Text $notificationTitleEnd -AppLogo $PSScriptRoot -Sound "Notification.Default" -SnoozeAndDismiss

Write-Output "The VHDX file has been created and compressed: $destinationPath"
