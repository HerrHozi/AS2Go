<#
.SYNOPSIS
Displays consistently formatted AS2Go console output.

.DESCRIPTION
Formats typed messages with the module's console conventions and forwards applicable output
to the logging helper.
Command displays a command with syntax highlighting without executing it. String literals are blue.
NextCommand displays a label, using "Next Command" when Message is omitted.

.PARAMETER Type
Output style. Use Command for highlighted command text or NextCommand for a command introduction.

.PARAMETER Message
Text to display, or command text to highlight when Type is Command.

.PARAMETER TextMaker
Additional highlighted text for output styles that support it.

.PARAMETER NoExtraLines
Suppresses surrounding blank lines for supported output styles, including Command and NextCommand.

.PARAMETER NoNewLine
Leaves the cursor on the same line for Command and NextCommand output.

.EXAMPLE
Write-AS2GoOutput -Type NextCommand -NoNewLine
Displays the default command introduction without a final newline.

.EXAMPLE
Write-AS2GoOutput -Type Command -Message "Get-Command -Module 'AS2Go'"
Displays the command with syntax highlighting without executing it.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Renders typed console messages and forwards them to logging.
#>
function 
Write-AS2GoOutput {

    ################################################################################
    #####                                                                      ##### 
    #####    Customize Output based on Type and Message                        #####                                
    #####                                                                      #####
    ################################################################################
    
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('T')]
        [ValidateSet("Info", "Input", "Success", "Warning", "Error", "CodeSnippet", "Command", "NextCommand", "TextMaker", "Header", "Bullet", "Quit", "H1", "OK", "BAD", "TOP" )]
        [string] $Type = "Info",
        [Parameter(Mandatory = $false, Position = 1)]
        [Alias('M')]
        [string] $Message,
        [Parameter(Mandatory = $false, Position = 2)]
        [Alias('TM')]
        [string] $TextMaker = "",
        [switch] $NoExtraLines,
        [switch] $NoNewLine
    )

    $CurrentFunction = Get-FunctionName
    #Write-Log -Message "### Start Function $CurrentFunction ###"
    #$StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    switch ($Type) {
        "Header" { 
            $width = 70
            $line = '_' * $width
            $padding = [math]::Max(0, [math]::Floor(($width - $Message.Length) / 2))
            $UpdatedText = ("{0}{1}" -f (' ' * $padding), $Message)
    
            Write-Host `n$line`n
            Write-Host $UpdatedText
            Write-Host $line`n
            $level = "INFO"
            $Message = "`n$line`n`n$UpdatedText`n$line`n"
        }
        "CodeSnippet" { 
            Write-Host "`n  [>] $Message`n"           -ForegroundColor $Script:FGCCommand 
            $level = "INFO"
        }
        "NextCommand" {
            if (-not $PSBoundParameters.ContainsKey('Message')) {
                $Message = "Next Command"
            }
            if (-not $NoExtraLines) { Write-Host "" }
            If ($NoNewLine) {
                Write-Host "  [>] $Message" -ForegroundColor $Script:FGCCommand -NoNewline
            }
            else {
                Write-Host "  [>] $Message" -ForegroundColor $Script:FGCCommand
                if (-not $NoExtraLines) { Write-Host "" }
            }
            $level = "INFO"
        }
        "Command" {
            $tokens = $null
            $parseErrors = $null
            [void][System.Management.Automation.Language.Parser]::ParseInput(
                [string]$Message, [ref]$tokens, [ref]$parseErrors
            )
            if (-not $NoExtraLines) { Write-Host "" }
            $position = 0
            foreach ($token in $tokens) {
                if ($token.Kind -eq 'EndOfInput') { continue }
                $start = $token.Extent.StartOffset
                if ($start -gt $position) {
                    Write-Host $Message.Substring($position, $start - $position) -NoNewline -ForegroundColor Gray
                }
                $color = switch ([string]$token.Kind) {
                    'StringLiteral' { 'Blue'; break }
                    'HereStringLiteral' { 'Blue'; break }
                    'StringExpandable' { 'Green'; break }
                    'HereStringExpandable' { 'Green'; break }
                    'Variable' { 'Green'; break }
                    'Number' { 'Yellow'; break }
                    'Parameter' { 'DarkGray'; break }
                    'Comment' { 'DarkGray'; break }
                    default {
                        if ($token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::CommandName) {
                            'Yellow'
                        }
                        elseif ($token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::Keyword) {
                            'Cyan'
                        }
                        else { 'Gray' }
                    }
                }
                Write-Host $token.Text -NoNewline -ForegroundColor $color
                $position = $token.Extent.EndOffset
            }
            if ($position -lt $Message.Length) {
                Write-Host $Message.Substring($position) -NoNewline -ForegroundColor Gray
            }
            if (-not $NoNewLine) {
                Write-Host ""
                if (-not $NoExtraLines) { Write-Host "" }
            }
            $level = "INFO"
        }
        "Warning" { 
            If ($NoExtraLines) {
                Write-host "  [!] " -NoNewline -ForegroundColor $Script:FGCWarning
                Write-Warning $Message
            }
            Else {
                Write-host "`n  [!] " -NoNewline -ForegroundColor $Script:FGCWarning
                Write-Warning "$Message`n`n"
            }   
            $level = "WARN" 
        }
        "Bullet" { 
            Write-host "  • $Message " -ForegroundColor $Script:FGCBullet -NoNewline
            Write-host "$TextMaker" -ForegroundColor $Script:FGCTextMaker
            $level = "INFO"
        }
        "Success" {
            If ($NoExtraLines) {
                Write-host "  [✅] $Message" -ForegroundColor $Script:FGCSuccess
            }
            Else {
                Write-host "`n  [✅] $Message`n`n" -ForegroundColor $Script:FGCSuccess
            }   

            #Write-Host "`n  [✓] $Message`n`n" -ForegroundColor DarkGreen
            $level = "INFO"
        }
        "Info" {
            If ($NoExtraLines) {
                Write-host "  [i] $Message"  #-ForegroundColor $Script:FGCSInfo
            }
            Else { 
                Write-Host "`n  [i] $Message`n`n" #-ForegroundColor $Script:FGCSInfo
            } 
            $level = "INFO"
        }
        "TextMaker" { 

            If ($NoExtraLines) {
                Write-host "  [i] $Message " -ForegroundColor $Script:FGCSInfo -NoNewline
                Write-host "$TextMaker" -ForegroundColor $Script:FGCTextMaker
            }
            Else { 
                Write-host "`n  [i] $Message " -ForegroundColor $Script:FGCSInfo -NoNewline
                Write-host "$TextMaker`n`n" -ForegroundColor $Script:FGCTextMaker
            } 

            $level = "INFO"
        }
        "Top" { 
            Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
            Write-host "$Message " -ForegroundColor $Script:FGCSInfo -NoNewline
            Write-host "$TextMaker" -ForegroundColor $Script:FGCTextMaker
            $level = "INFO"
        }
        "Bad" { 
            Write-Host "     BAD: " -NoNewline -ForegroundColor Red
            Write-host "$Message " -ForegroundColor $Script:FGCSInfo -NoNewline
            Write-host "$TextMaker" -ForegroundColor $Script:FGCTextMaker
            $level = "INFO"
        }
        "OK" { 
            Write-Host "      OK: " -NoNewline -ForegroundColor Yellow
            Write-host "$Message " -ForegroundColor $Script:FGCSInfo -NoNewline
            Write-host "$TextMaker" -ForegroundColor $Script:FGCTextMaker
            $level = "INFO"
        }
        "Input" { 
            Write-Host "`n  [~] $Message"           -ForegroundColor $Script:FGCInput -NoNewLine
            $answer = Read-Host ":"  
            Write-Host "`n"
            $level = "INFO"
        }
        "Quit" { 
            Write-Host "`n  [~] $Message`n`n"           -ForegroundColor $Script:FGCError
            $level = "INFO"
        }
        "Error" { 
            Write-Host "`n  [X] ERROR: $Message`n`n"    -ForegroundColor $Script:FGCError
            $level = "ERROR"
        }
        "H1" { 
            Write-Host "$Message`n"    -ForegroundColor $Script:FGCH1
            $level = "INFO"
        }
        default { 
            Write-Host "`n  [i] $Message`n`n"           -ForegroundColor $Script:FGCSInfo
            $level = "INFO" 
        }
    }

    #[ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
    Write-Log -Message "### $CurrentFunction >> $Type | $Message $TextMaker" -Level $level

    ######################## main code ############################
    #$runtime = Get-RunTime -StartRunTime $StartRunTime
    #Write-Log -Message "    Run Time: $runtime [h] ###"
    #Write-Log -Message "### End Function $CurrentFunction ###"

    If ($Type -eq "Input") {
        return $answer
    }

}
