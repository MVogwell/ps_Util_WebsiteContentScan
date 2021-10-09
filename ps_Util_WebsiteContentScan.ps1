### ps_Util_WebsiteStringScan.ps1
# Purpose: Search an initial website url for a regex pattern then open and search all sites linked to the initial site

[CmdletBinding()]
param (
    [Parameter (mandatory=$true)][uri]$url,                         # This is the url to start scanning
    [Parameter (mandatory=$true)][string]$SearchRegex,              # This is the string (text) search criteria in regex form.
    [Parameter (mandatory=$false)][string]$ExactKeyword,            # Optional. This is the extract string search criteria to look for if a page matches the regex
    [Parameter (mandatory=$false)][string[]]$arrDomainExceptions,   # This is an array of domains to skip (in case the script calls them but you don't want their results)
    [Parameter (mandatory=$false)][string[]]$arrPageExceptions      # This is an array of specific page URL addresses to skip - this will skip all sub-pages as well
)

Function Get-PageLinks() {
    param (
        [Parameter (mandatory=$true)]$objContent,
        [Parameter (mandatory=$true)][string]$sBaseDomain,
        [Parameter (mandatory=$true)][string]$sBaseUri
    )

    # Function purpose: Parse the returned page links, including building a full url from relative url links, and return an array.

    # Initialise the empty array that will contains the links
    $arrReturnUrl = @()
    
    #@# Loop through each link returned by Invoke-WebRequest using the .Links property.
    foreach ($l in $objContent.Links) {
        # Tidy up the data returned in the link
        if ($l.outerHTML -match "^<a href.*") {         # Check that the link is "valid" 
            $u = $l.outerHTML.substring(9)              # Remove "<a href="
            $u = $u.split("""")[0]                      # Isolate the URL from the end double quotes
            $u = $u.split(">")[0]                       # Isolate the URL from the closing anchor bracket
    
            if (!([string]::IsNullOrEmpty($u))) {               # Check the string isn't empty
                if (!($u -match "^#")) {                        # Check the link isn't to an anchor in the same page
                    if(!($u.Split("."[0]) -match ".*@.*")) {    # Check the first part of the url doesn't contain an @ symbol - it happens
                        if ($u -match "^/") {                       # If the link is relative not absolute add the url as the prefix
                            try {
                                # Add the base url
                                $u = $sBaseUri + $u
                            }
                            catch {
                                # Set the $u variable containing the url to error if the base url could not be extracted
                                $u = "!!!ERROR!!!"
                                Write-Verbose "Failed to extract base URI"
                            }                            
                        }

                        # Only continue if the base url could be discovered
                        if (!($u -eq "!!!ERROR!!!")) {
                            # Remove "/"" if it is the last character
                            if ($u.substring($u.length-1) -eq "/") {
                                    $u = $u.substring(0,$u.length-1)
                            }

                            # Add the processing order prefix. This means if the host part of the url matches the initial search url 
                            # domain then a 1 will be added to indicate that it should be added. If the url isn't directly from the 
                            # initial specified domain then a 2 will be added.
                            try {
                                if ($u -match $sBaseDomain) {
                                    $u = "1" + $u
                                }
                                else {
                                    $u = "2" + $u
                                }
                            }
                            catch {
                                $u = "2" + $u
                            }

                            # Check the array of linked url doesn't already contain this url - this prevents duplicate links to the same
                            # page in the returned Links property from being added.
                            if (!($arrReturnUrl -contains $u))    {       
                                $arrReturnUrl += $u
                            }
                        } # End of: Only continue if the base url could be discovered
                    } # End of: Check the first part of the url doesn't contain an @ symbol - it happens
                } # End of: Check the link isn't to an anchor in the same page
            } # End of: Check the string isn't empty
        } # End of: Check that the link is "valid" 
    } # End of: Loop through each link returned by Invoke-WebRequest using the .Links property.

    return $arrReturnUrl
} # End of: Get-PageLinks


Function Start-UrlStringSearch() {
    param (
        [Parameter (mandatory=$true)][string]$url,          # This is the url to test
        [Parameter (mandatory=$true)][string]$sBaseDomain,  # This is the original base url (used for comparison of the sub-links)
        [Parameter (mandatory=$true)][ref]$objResult,       # Note: ref object returns the information about the site
        [Parameter (mandatory=$true)][string]$sSearchRegex, # This is the regex pattern to look for in the returned webpage content data
        [Parameter (mandatory=$true)][string]$sExactKeyword # This is the string to look for in the returned data (so long as the regex matches)
    )

    # Purpose of function: Given a url to scan, Invoke-WebRequest and return the data from the page and available links
    # then check whether the content of the page matches the regex search criteria. If a match is found then check for the
    # Exact keyword (if specified in the startup parameters). Next parse any links using the function Get-PageLinks and 
    # return an object containing the results.

    # Initialise the array that will contains any links
    $arrPageLinks = $null

    # Remove any trailing / from the end of the url
    if ($url.substring($url.length-1) -eq "/") {
        $url = $url.substring(0,$url.length-1)
    }

    # Attempt to get the content from the webpage
    try {
        $objContent = (Invoke-WebRequest -Uri $url.Substring(1) -UseBasicParsing -Verbose:$false | Select-Object Links,RawContent)

        Write-Verbose "`n`tScan complete"
    }
    catch {
        $objContent = $null
        $objResult.Value.PageScannedOk = $false
        $objResult.Value.ScanErrMsg = ($Error[0].Exception.Message).Replace("`n","").Replace("`r","")
    }

    # Scan the page content for the regex pattern
    try {
        if (!($null -eq $objContent)) {
            Write-Verbose "`tRegex Scan Starting"

            if ($objContent.RawContent -match $searchRegex) {
                $objResult.Value.Content = $objContent.RawContent
                $objResult.Value.RegexDiscovered = $true
            }
        }
    }
    catch {
        $objResult.Value.PageScannedOk = $false
    }

    # Attempt to extract the ExtractKeyword data
    if ($sExactKeyword -ne "!!!NOTINUSE!!!") {      # Only continue if a ExtractKeyword string was specified at startup. If no string was specified the value will be !!!NOTINUSE!!!
        Write-Verbose "`tExtractKey Scan"

        # Check for the index of the first instance of the phrase (using IndexOf) and return the matched string (if found)
        try {
            $iIndex = ($objContent.RawContent).IndexOf($sExactKeyword)
            if ($iIndex -ge 0) {    # The Extract keyword was found
                $objResult.Value.ExtractKeyword = ($objContent.RawContent).SubString($iIndex,$sExactKeyword.Length)
            }
            else {
                $objResult.Value.ExtractKeyword = "Not Found"    
            }
        }
        catch {
            $objResult.Value.ExtractKeyword = "Error"
        }
    }
    

    # Only parse the page links if they have not been discoverd
    if (!($null -eq $objContent.Links)) {
        Write-Verbose "`tGetting links"

        try {
            # Extract the base url/uri using the system.uri class
            [uri]$sSiteUri = $url.Substring(1)
            $sBaseUri = $sSiteUri.Scheme + "://" + $sSiteUri.Host

            # Use the Get-PageLinks function to parse links returned by the page lookup
            $arrPageLinks = Get-PageLinks -objContent $objContent -sBaseDomain $sBaseDomain -sBaseUri $sBaseUri

            Write-Verbose "`tPage links found: $($arrPageLinks.Length)"
        }
        catch {
            Write-Host "`t... Unable to build base uri"
        }
    }

    return $arrPageLinks
}



#@# Main

Write-Host "`n`nps_Util_WebsiteStringScan" -ForegroundColor Green
Write-Host "MVogwell - v1.0 20211009-1313 `n`n" -ForegroundColor Green

#@# Initialise variables
[console]::TreatControlCAsInput = $true

# Check the value entered for url is valid
try {
    $sBaseDomain = ".*" + ($url.Host).Replace("www.","") + ".*"
    $url = "1" + $url
}
catch {
    Write-Host "The value for -url is invalid. The script will now exit `n`n" -ForegroundColor Red
    Exit
}

# If there are no entries on startup for arrDomainExceptions then create an empty array
if([string]::IsNullOrEmpty($arrDomainExceptions)) {
    $arrDomainExceptions = @()
}

# If there are no entries on startup for arrDomainExceptions then create an empty array
if([string]::IsNullOrEmpty($arrPageExceptions)) {
    $arrPageExceptions = @()
}

# Create an empty array to hold the list of pages scanned by the script
# This is used to prevent the script from looping to pages already scanned
$arrAlreadyScannedPages = @($url)
$arrResults = @()
$arrPagesToScan = @()

# Display search criteria
Write-Host "Initial site: $($url.toString().Substring(1))" -ForegroundColor Cyan
Write-Host "Regex search pattern: $searchRegex" -ForegroundColor Cyan

# Check whether a value for ExactKeyword has been used
if ([string]::IsNullOrEmpty($ExactKeyword)) {
    $ExactKeyword = "!!!NOTINUSE!!!"
}
else {
    Write-Host "ExactKeyword to check for on search confirmation: $ExactKeyword" -ForegroundColor Cyan
}

Write-Host "Starting scan... `n" -ForegroundColor Cyan

Write-Host "Press Ctrl+C to cancel the scan... `n" -ForegroundColor Yellow

Write-Host "QueueLength :: Page# :: Url :: Regex Found `n" -ForegroundColor Green

Do {
    # Listen for Ctrl+C and exit
    if ([console]::KeyAvailable) {
        $key = [system.console]::readkey($true)
        if (($key.modifiers -band [consolemodifiers]"control") -and ($key.key -eq "C"))  {
            Write-Host "`n`nExiting... `n" -ForegroundColor Green

            break
        }
        elseif ($key.key -eq "R") {
            $arrResults | Out-GridView
        }
        elseif ($key.key -eq "T") {
            $arrPagesToScan | Out-GridView
        }
    }

    # If available, get the page that the url was called from
    try {
        $sCallingPage = (($arrAlreadyScannedPages | Where-Object {$_.sPageToScan -eq $url.toString()} | Select-Object CallingPage).CallingPage).Substring(1)
    }
    catch {
        $sCallingPage = ""
    }

    # This is the "results" object for this URI as well as containing a "history" of the number of URI in the scan queue
    # as well as the number of URI that have been scanned
    $objResult = [PSCustomObject] @{
        UrlScanQueue = $arrPagesToScan.Length
        ScanNumber = $arrAlreadyScannedPages.Length
        Url = $url.toString().Substring(1)
        PageScannedOk = $true
        RegexDiscovered = $false
        ExtractKeyword = ""
        Content = ""
        CallingPage = $sCallingPage
        ScanErrMsg = ""
    }

    Write-Host "$($objResult.UrlScanQueue) :: $($objResult.ScanNumber) :: $($objResult.Url)" -ForegroundColor Yellow -NoNewline

    # Initiate search for the regex pattern AND also get any links from the webpage
    $arrPageLinks = Start-UrlStringSearch -url $url -sBaseDomain $sBaseDomain -objResult ([ref]$objResult) -sSearchRegex $SearchRegex -sExactKeyword $ExactKeyword

    if ($objResult.PageScannedOk -eq $false) {
        Write-Host " :: Error Scanning" -ForegroundColor Red
    }
    else {
        Write-Host " :: $($objResult.RegexDiscovered)" -ForegroundColor Green
    }

    # Add to the result the array of results
    $arrResults += $objResult

    # From the links returned from the page - check they haven't already been processed (arrAlreadyScannedPages) or are on the
    # list to be processed (arrPagesToScan). If the uri passes the check then add it, along with the current uri which called it
    # to the array containing the list of pages to scan.
    foreach ($sPageLink in $arrPageLinks) {
        if ((!($arrPagesToScan.sPageToScan -contains $sPageLink)) -and (!($arrAlreadyScannedPages.sPageToScan -contains $sPageLink))) {
            try {
                # Check the page being added is a valid URI
                [uri]$uPageToScan = $sPageLink.toString().Substring(1)

                # Check the uPageToScan isn't on the exceptions list
                if ((!($arrDomainExceptions -contains $uPageToScan.Host)) -and (!($arrPageExceptions -contains $sPageLink.toString().Substring(1)))) {

                    # Only call a page if it is linked to the original site
                    if ($url.toString() -match $sBaseDomain) {
                        $arrPagesToScan += New-Object -TypeName PSCustomObject -Property @{CallingPage=$($url.toString());sPageToScan=$sPageLink}
                    }
                }
            }
            catch {
                Write-Verbose "ERROR: Unable to add uri $sPageToScan to the list of pages to scan. Error: $(($Error[0].Exception.Message).Replace('`n','').Replace('`r',''))"
            }
        }
    }

    # Check if there are more pages to scan. If there are then; sort the remaining list so that sites matching the Base Uri come first
    # then extract the top uri to scan. Also move the uri to scan from "arrPagesToScan" to "arrAlreadyScannedPages"
    if ($arrPagesToScan.Length -gt 0) {
        # Sort the pages so the native URL is called first (as it is prefixed with 1)
        $arrPagesToScan = $arrPagesToScan | Sort-Object sPageToScan    # Sort the list of pages to scan. As the base

        # Queue up the next page to scan
        [uri]$url = $arrPagesToScan[0].sPageToScan

        # Move the page from arrPagesToScan (the 'to do' list) to arrAlreadyScannedPages (the 'done' list)
        $arrAlreadyScannedPages += $arrPagesToScan | Where-Object {$_.sPageToScan -eq $url}
        $arrPagesToScan = $arrPagesToScan | Where-Object {$_.sPageToScan -ne $url}
    }

} While ($arrPagesToScan.Length -gt 0)

Write-Host "`nOutputting results... `n" -ForegroundColor Yellow

# Option to view the results on screen
Do {
    $sResponse = Read-Host "Do you want to view the results on screen? (yes/no) [Default: Yes]"
    if ($sResponse -eq "") {
        $sResponse = "y"
    }
}
While ($sResponse -notmatch "y|yes|n|no")

if ($sResponse -match "y|yes") {
    if ($ExactKeyword -eq "!!!NOTINUSE!!!") {
        $arrResults | Select-Object ScanNumber,Url,PageScannedOk,RegexDiscovered,CallingPage | Out-GridView
    }
    else {
        $arrResults | Select-Object ScanNumber,Url,PageScannedOk,RegexDiscovered,ExtractKeyword,CallingPage | Out-GridView
    }
}


# Export the page(s) content (if requested) where the regex string was discovered - only available if the regex pattern was discovered
if (($arrResults | Where-Object {$_.RegexDiscovered -eq $true} | Measure-Object).Count -gt 0) {
    Do {
        $sResponse = Read-Host "`nDo you want to save the page contents where the regex pattern was discovered? (yes/no) [Default: No]"
        if ($sResponse -eq "") {
            $sResponse = "n"
        }
    }
    While ($sResponse -notmatch "y|yes|n|no")

    # Continue if user responds y
    if ($sResponse -match "y|yes") {
        $bProceed = $true

        # Create a folder for the results to go into:
        try {
            $sOutputFolder = $Env:TEMP + "\WebsiteStringScan_Summary_" + $(Get-Date -Format "yyyyMMdd-HHmmss")
            
            Write-Host "`t... Creating output folder: " -ForegroundColor Yellow -NoNewline
            
            New-Item $sOutputFolder -ItemType Directory -Force | Out-Null

            Write-Host "Success" -ForegroundColor Green
        }
        catch {
            $bProceed = $false
        }

        if ($bProceed -eq $true) {
            # Loop through the results where the regex was discovered and export the content
            $arrResults | Where-Object {$_.RegexDiscovered -eq $true} | ForEach-Object {
                $sFilePath = $sOutputFolder + "\WebsiteStringScan_Site_" + $_.ScanNumber + ".txt"

                try {
                    Write-Host "`tFile: $sFilePath" -ForegroundColor Yellow -NoNewline
                    
                    $_.Content | Out-File $sFilePath -Encoding utf8

                    Write-Host " :: Exported" -ForegroundColor Green
                }
                catch {
                    $sErrMsg = ("Failed. Error: " + $(($Error[0].Exception.Message).Replace("`n","").Replace("`r","")))
                    Write-Host "`t`t$sErrMsg `n" -ForegroundColor Red
                }
            }
        }
    }
}

# Option to view the results on screen
Do {
    $sResponse = Read-Host "`nDo you want to save the summary results to file? (yes/no) [Default: No]"
    if ($sResponse -eq "") {
        $sResponse = "no"
    }
}
While ($sResponse -notmatch "y|yes|n|no")


# Output the summary data to file - report on error
if ($sResponse -match "y|yes") {
    Write-Host "`t... Saving to file: " -ForegroundColor Yellow -NoNewline

    try {
        # Write the results file in csv format to the temp directory

        $sOutputFile = $Env:TEMP + "\WebsiteStringScan_Summary_" + $(Get-Date -Format "yyyyMMdd-HHmmss") + ".csv"
        
        $arrResults | Select-Object ScanNumber,Url,PageScannedOk,RegexDiscovered,ExtractKeyword,CallingPage,ScanErrMsg | Export-Csv $sOutputFile -NoTypeInformation

        Write-Host "`t`tSuccess `n" -ForegroundColor Green
    }
    catch {
        $sErrMsg = ("Failed. Error: " + $(($Error[0].Exception.Message).Replace("`n","").Replace("`r","")))
        Write-Host "`t`t$sErrMsg `n" -ForegroundColor Red
    }

    # Open the csv file
    try {
        if ((Test-Path $sOutputFile) -eq $true) {
            Write-Host "`t... Opening results summary file: " -ForegroundColor Yellow -NoNewline

            Invoke-Expression $sOutputFile

            Write-Host "$sOutputFile" -ForegroundColor Green
        }
    }
    catch {
        $sErrMsg = ("Failed. Error: " + $(($Error[0].Exception.Message).Replace("`n","").Replace("`r","")))
        Write-Host "`t`t$sErrMsg `n"
    }
}

Write-Host "`n`nScript Completed.`n`n" -ForegroundColor Green