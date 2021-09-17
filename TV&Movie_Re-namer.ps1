# Start Location of Downloads
$path = $env:HOMEPATH + "\Downloads\TVM\"

# Location of where movies and tv shows will be moved too
$finalPath = "Z:\M-T\"

# Movie Regex
$MovieRegex = '[12]{1}[09]{1}[0-9]{2,}'

# TV regex Array
$TVRegex = @('([sS][0-9]{2,})','([eE][0-9]{2,3})')

# Video type array
$VideoType = @(".mp4",".avi",".mkv")

# Subtitle tpye array
$SubType = @(".srt",".sub")

Function GetLocation {
    param (
        [parameter(Mandatory=$true)]
        $Path
    )
    $ls = Get-ChildItem -LiteralPath $Path
    return $ls
}

Function DetectOpositeType {
    param (
        [parameter(Mandatory=$true)]
        $Files,
        [parameter(Mandatory=$true)]
        $For
    )
    foreach ($item in $Files) {
        $x = 0
        foreach ($type in $For) {
            if ($item -like $type) {
                $x ++
                break
            }
            $x ++
            if ($x -eq $For.Count) {
                [array]$NotType += $item
            }
        }
    }
    return $NotType
}

Function DetectType {
    param (
        [parameter(Mandatory=$true)]
        $Files,
        [parameter(Mandatory=$true)]
        $For
    )
    foreach ($item in $Files) {
        foreach ($type in $For) {
            if ($item.Extension -like $type) {
                [array]$Detected += $item
            }
        }
    }
    return $Detected
}

Function IdentifyName {
    param (
        [parameter(Mandatory=$true)]
        $Name,
        [parameter(Mandatory=$true)]
        $Type
    )
    $nameArray = $Name -Split '\W'
    foreach ($word in $nameArray) {
        if ($Type -eq "Movie") {
            if ($word -match $MovieRegex) {
                [array]$newName += $word
                [String]$newName = $newName
                return $newName
            }
            else {
                [array]$newName += $word
            }
        }
        if ($Type -eq "Show") {
            if (($word -match $TVRegex[0]) -or ($word -match $TVRegex[1])) {
                if ($word -match $TVRegex[0]) {
                    $word = $word.Split("[sS]")
                    if ($word -match "e") {
                        $word = $word.Split("[eE]")
                        [string]$word = "Season " + $word[1]
                        [array]$newName += $word
                        [String]$newName = $newName
                        return $newName
                    }
                    [string]$word = "Season " + $word[1]
                    [array]$newName += $word
                    [String]$newName = $newName
                    return $newName
                }
                if ($word -match $TVRegex[1]) {
                    $word = $word.Split("[eE]")
                    [string]$word = "Episode " + $word[1]
                    [array]$newName += $word
                    [String]$newName = $newName
                    return $newName
                }
            }
            if ($word -match $MovieRegex) {
                continue       
            }
            else {
                [array]$newName += $word
            }
        }
    }
}

Function GetSubFolder {
    param (
        [parameter(Mandatory=$true)]
        $Name,
        [parameter(Mandatory=$true)]
        $Type
    )
    $CurrentName = $Name.Split(" ")
    $count = $CurrentName.Count
    $endOfArray = $count - 1
    $startOfSubFolder = $count -2
    $endOfName = $count - 3

    if ($Type -match "NewName") {
        [string]$NewName = $CurrentName[0..$endOfName]
        return $NewName
    }
    if ($Type -match "SubFolder") {
        [string]$NewName = $CurrentName[$startOfSubFolder..$endOfArray]
        return $NewName
    }
}

Function ContentCheck {
    param (
        [parameter(Mandatory=$true)]
        $Name
    )
    if (($Name -match $TVRegex[0]) -or ($Name -match $TVRegex[1])) {
        [array]$contentType = @([PSCustomObject]@{Type="Show";OldName="$Name";NewName="";Files="";SubFolder=""})
        $Name = IdentifyName -Name $contentType.OldName -Type $contentType.Type
        $contentType[0].NewName = GetSubFolder -Name $Name -Type "NewName"
        $contentType[0].Files = GetFolderFiles -Folder $item
        $contentType[0].SubFolder = GetSubFolder -Name $Name -Type "SubFolder"
        return $contentType
    }
    if ($Name -match '[12]{1}[90]{1}[0-9]{2,}') {
        [array]$contentType = @([PSCustomObject]@{Type="Movie";OldName="$Name";NewName="";Files="";SubFolder=""})
        $contentType[0].NewName = IdentifyName -Name $contentType.OldName -Type $contentType.Type
        $contentType[0].Files = GetFolderFiles -Folder $item
        $contentType[0].SubFolder = "Subtitles"
        return $contentType
    }
}

Function GetFolderFiles {
    param (
        [parameter(Mandatory=$true)]
        $Folder
    )
    [array]$files = Get-ChildItem -LiteralPath $Folder.FullName -include "$item" -depth 10

    foreach ($file in $files) {
        [array]$actualFiles += DetectType -Files $file -For $VideoType
        [array]$actualFiles += DetectType -Files $file -For $SubType
    }

    return $actualFiles
}

Function GetFileName {
    param (
        [parameter(Mandatory=$true)]
        $File
    )
    $Name = $File.Name -Split '\W'
    foreach ($word in $Name) {
        if ($word -match $TVRegex[1]) {
            if ($word -match $TVRegex[0]) {
                $word = $word.Split("[eE]")
                [string]$name = "E" + $word[1]
                return $name
            }
            else {
                return $word
            }
        }
    }
}

$items = GetLocation -Path $path

foreach ($item in $items) {
    [array]$type += ContentCheck -Name $item.Name
}

$dir = GetLocation -Path $finalPath

foreach ($item in $type) {
    foreach ($folder in $dir) {
        if ($folder.Name -match "Movie") {
            if ($item.Type -match "Movie") {
                foreach ($file in $item.Files) {
                    foreach ($fileType in $VideoType) {
                        if ($file.Extension -match $fileType) {
                            # Video
                            $folderName = $folder.FullName + "\" + $item.NewName + "\"
                            New-Item -Path $folderName -ItemType Directory

                            $subsFolder = $folderName + $item.SubFolder +"\"
                            New-Item -Path $subsFolder -ItemType Directory

                            $newName = $folderName + $item.NewName + $file.Extension
                            $Path = $file.FullName
                            Copy-Item -LiteralPath "$Path" -Destination "$newName"
                        }
                    }
                    foreach ($fileType in $SubType) {
                        if ($file.Extension -match $fileType) {
                            # Subtitle
                            $Path = $file.FullName
                            Copy-Item -LiteralPath "$Path" -Destination "$subsFolder"
                        }
                    }
                }
            }
        }
        if ($folder.Name -match "Show") {
            if ($item.Type -match "Show") {
                foreach ($file in $item.Files) {
                    foreach ($fileType in $VideoType) {
                        if ($file.Extension -match $fileType) {
                            # Video
                            $folderName = $folder.FullName + "\" + $item.NewName + "\" + $item.SubFolder + "\"
                            if (Test-Path -LiteralPath $folderName) {}
                            
                            else {
                                New-Item -Path $folderName -ItemType Directory
                            }

                            $fileName = GetFileName -File $file
                            
                            $newName = $folderName + $fileName + $file.Extension
                            $Path = $file.FullName
                            Write-Host $newName
                            Write-Host $Path
                            Copy-Item -LiteralPath "$Path" -Destination "$newName" -Force
                        }
                    }
                    foreach ($fileType in $SubType) {
                        if ($file.Extension -match $fileType) {
                            # Subtitle
                            $Path = $file.FullName
                            Copy-Item -LiteralPath "$Path" -Destination "$subsFolder"
                        }
                    }
                }
            }
        }
    }
}