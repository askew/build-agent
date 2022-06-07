<#
.SYNOPSIS
Encodes and embeds a script file into a Cloud-Init file

.DESCRIPTION
The Cloud-Init file includes a section to write a script file to disk before running the script.
The script-file is GZip compressed and Base64 encoded before being embedded in the cloud-init.
The cloud-init file must contain the placeholder text "INSTALLSCRIPT" that will be replaced with the encoded script file.
The generated cloud-init file is named with a .out extension

.PARAMETER  cloudInitFile
The path to the cloud-init file.

.PARAMETER  installScript
The path of the script file to embed.

.PARAMETER  placeholderText
The placeholder text in the could-config file to be replaced with the encoded file.

.EXAMPLE
.\BuildVMCloudInit.ps1 -cloudInitFile 'cloud-config.yml' -installScript 'vstsagent.sh'
#>

param (
    [Parameter(Mandatory = $true)]
    [String]
    $cloudInitFile,

    [Parameter(Mandatory = $true)]
    [String]
    $installScript,

    [Parameter(Mandatory = $false)]
    [String]
    $placeholderText = "INSTALLSCRIPT"
)

function GZipText {
  param (
    [string]
    $inputText
  )
  $data =  [Text.Encoding]::UTF8.GetBytes($inputText)
  $output = [System.IO.MemoryStream]::new()
  $gzipStream = New-Object System.IO.Compression.GzipStream $output, ([IO.Compression.CompressionMode]::Compress)
  $gzipStream.Write($data, 0, $data.Length)
  $gzipStream.Close()
  return $output.ToArray()
}

# Make sure the install script has LF end-of-lines and is UTF8 encoded.
$gzipData = GZipText -inputText (Get-Content $installScript | Join-String -Separator "`n")
$base64Script = [Convert]::ToBase64String($gzipData)

# Replace the placeholder text in the cloud-init with the encoded script
$init = Get-Content $cloudInitFile `
  | ForEach-Object { $_ -replace $placeholderText, "$base64Script" } `
  | Join-String -Separator "`n"

$gzipCloudConfig = GZipText -inputText $init

# Now GZip and base-64 encode the cloud-init file.
$extn = Split-Path $cloudInitFile -Extension
$outfilename = Split-Path -Path ([System.IO.Path]::ChangeExtension($cloudInitFile, "$($extn).gz")) -Leaf
$outdir = Join-Path -Path (Split-Path (Resolve-Path $cloudInitFile) -Parent) -ChildPath 'out'
$outfile = Join-Path -Path $outdir -ChildPath $outfilename

if (!$(Test-Path $outdir -PathType Container))
{
  New-Item -Path $outdir -ItemType Directory | Out-Null
}

Set-Content -Path $outfile -Value $gzipCloudConfig -AsByteStream

# SIG # Begin signature block
# MIIfpQYJKoZIhvcNAQcCoIIfljCCH5ICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUkuFIDnR3PFB6OW/wLJJ4YjnH
# FXegghjDMIIFMDCCBBigAwIBAgIQBAkYG1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0B
# AQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIwMDAwWhcNMjgxMDIyMTIwMDAwWjByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# Q29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
# +NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrbRPV/5aid2zLXcep2nQUut4/6kkPApfmJ
# 1DcZ17aq8JyGpdglrA55KDp+6dFn08b7KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0
# sSgmuyRpwsJS8hRniolF1C2ho+mILCCVrhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6s
# cKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4Tz
# rGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWOD8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg
# 0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IBzTCCAckwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMweQYIKwYBBQUH
# AQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYI
# KwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaG
# NGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcmwwTwYDVR0gBEgwRjA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0
# dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYE
# FFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IBAQA+7A1aJLPzItEVyCx8JSl2qB1dHC06
# GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew4fbRknUPUbRupY5a4l4kgU4QpO4/cY5j
# DhNLrddfRHnzNhQGivecRk5c/5CxGwcOkRX7uq+1UcKNJK4kxscnKqEpKBo6cSgC
# PC6Ro8AlEeKcFEehemhor5unXCBc2XGxDI+7qPjFEmifz0DLQESlE/DmZAwlCEIy
# sjaKJAL+L3J+HNdJRZboWR3p+nRka7LrZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4Gb
# T8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiFLpKR6mhsRDKyZqHnGKSaZFHvMIIGDzCC
# BPegAwIBAgIQCboqa7YdhGGpWisLVohBRjANBgkqhkiG9w0BAQsFADByMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBMB4XDTIwMDUzMDAwMDAwMFoXDTIzMDYwNzEyMDAwMFowTDEL
# MAkGA1UEBhMCR0IxDTALBgNVBAcTBEJhdGgxFjAUBgNVBAoTDVN0ZXBoZW4gQXNr
# ZXcxFjAUBgNVBAMTDVN0ZXBoZW4gQXNrZXcwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQDQ1RO3hrcnnX8faM+5wG1c0ZUQn/B1FT2Khio7RnJ705OXJCat
# ErTERpukVGTf0uaQjOlp9tNHFXcfGiSjGRH4GBZFkG2dL/zsCvxYf4odhEJlwn7K
# W2SHpldF35JwJjrFLRqLHWsOANPwJQfeL0Ks6BgGlOPJeYIkH53MVyQIajLE38Nb
# XRTVeL4D/N/3twJf/jA+ufSj32lozyDcIOBnoKtMCagDXBtScOyZZqlVgYARmekL
# bIkt+FMvaXWZPx3zQjsHdRibcKc+nm4ADXGdMLG340ZYOCa88UfilN3iuxQ7v1O8
# SDuFQzbIQEaaea0/va/sVyX41y3Oq6GUk8McawiiUqfk6wkuyt25ORv4U1aoXXfz
# lFz73SDz5vVespcVW5aDbh4gTwa265JJMYpbFb+/on/jSCqm/joKO2RMxepba30T
# xqHmCQ3pWRBaP5OFdJGK+VgJ1txEj+LW+z+v2HajWENi/1kQyJY1KDPnZSh5nGAv
# XuaBfaTkbEz5Z5TjoGDx4gyZb8uGgsaYgW6+dfXG/9EGpbMVydT6KEGLZahq9NOw
# PGTXvq9yyeafLQa18vvbYMbZpRBoNCAcaYYNxwF2sFBMdujfX2OFj3Gs+AnHe+JY
# y+yXjiK4/zjdhXhwfYrSWOfxhEz/Yvl0iHxb3XAlmRJIlh+asRQjA2lUZQIDAQAB
# o4IBxTCCAcEwHwYDVR0jBBgwFoAUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0O
# BBYEFKJYrum8GmNEpSgD4V73lbxbNmWkMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUE
# DDAKBggrBgEFBQcDAzB3BgNVHR8EcDBuMDWgM6Axhi9odHRwOi8vY3JsMy5kaWdp
# Y2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDA1oDOgMYYvaHR0cDovL2Ny
# bDQuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwTAYDVR0gBEUw
# QzA3BglghkgBhv1sAwEwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNl
# cnQuY29tL0NQUzAIBgZngQwBBAEwgYQGCCsGAQUFBwEBBHgwdjAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsGAQUFBzAChkJodHRwOi8v
# Y2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEyQXNzdXJlZElEQ29kZVNp
# Z25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAQEAaenS
# W9qLgXgpfF0mpg99Hes7h+chavi2mS8ykzMB8/NC9I/eP1K+4UHo0+jwsMhhkXGR
# WvFbzNFOtaWzYq3RZ15AZgg7vmKBqikpNmzDPl1M+vYqPbSmBwhcKQgQnCLBFHD+
# jLZyFCgY7mD4jPMhdtKwVPtmDSFio4YW9gYA/CWNVg3TQrn3vVZRLDB40k71TkFX
# 5E1KYYdhPf7e+5VnmDtqHAoRnzP7/VSAsdU7ELUXjbwzuT30MhxcxMeHCxvHsx5k
# UCl7HN9yFYXJWYpIwvgmSYDJiZ6SYirbFA72bn6VoTPz4kKRuCoJzxyoKVPSfwb+
# TSvFhIkYD4XlwvEuwzCCBq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJ
# KoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQg
# VHJ1c3RlZCBSb290IEc0MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVow
# YzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQD
# EzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGlu
# ZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklR
# VcclA8TykTepl1Gh1tKD0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54P
# Mx9QEwsmc5Zt+FeoAn39Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupR
# PfDWVtTnKC3r07G1decfBmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvo
# hGS0UvJ2R/dhgxndX7RUCyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV
# 5huowWR0QKfAcsW6Th+xtVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYV
# VSZwmCZ/oBpHIEPjQ2OAe3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6i
# c/rnH1pslPJSlRErWHRAKKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/Ci
# PMpC3BhIfxQ0z9JMq++bPf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5
# K6jzRWC8I41Y99xh3pP+OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oi
# qMEmCPkUEBIDfV8ju2TjY+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuld
# yF4wEr1GnrXTdrnSDmuZDNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAG
# AQH/AgEAMB0GA1UdDgQWBBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAW
# gBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAww
# CgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8v
# b2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDow
# OKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRS
# b290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkq
# hkiG9w0BAQsFAAOCAgEAfVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvH
# UF3iSyn7cIoNqilp/GnBzx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0M
# CIKoFr2pVs8Vc40BIiXOlWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCK
# rOX9jLxkJodskr2dfNBwCnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rA
# J4JErpknG6skHibBt94q6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZ
# xhOACcS2n82HhyS7T6NJuXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScs
# PT9rp/Fmw0HNT7ZAmyEhQNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1M
# rfvElXvtCl8zOYdBeHo46Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXse
# GYs2uJPU5vIXmVnKcPA3v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWY
# MbRiCQ8KvYHZE/6/pNHzV9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYp
# hwlHK+Z/GqSFD/yYlvZVVCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPww
# ggbGMIIErqADAgECAhAKekqInsmZQpAGYzhNhpedMA0GCSqGSIb3DQEBCwUAMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0EwHhcNMjIwMzI5MDAwMDAwWhcNMzMwMzE0MjM1OTU5WjBMMQswCQYDVQQGEwJV
# UzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xJDAiBgNVBAMTG0RpZ2lDZXJ0IFRp
# bWVzdGFtcCAyMDIyIC0gMjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# ALkqliOmXLxf1knwFYIY9DPuzFxs4+AlLtIx5DxArvurxON4XX5cNur1JY1Do4Hr
# OGP5PIhp3jzSMFENMQe6Rm7po0tI6IlBfw2y1vmE8Zg+C78KhBJxbKFiJgHTzsNs
# /aw7ftwqHKm9MMYW2Nq867Lxg9GfzQnFuUFqRUIjQVr4YNNlLD5+Xr2Wp/D8sfT0
# KM9CeR87x5MHaGjlRDRSXw9Q3tRZLER0wDJHGVvimC6P0Mo//8ZnzzyTlU6E6XYY
# mJkRFMUrDKAz200kheiClOEvA+5/hQLJhuHVGBS3BEXz4Di9or16cZjsFef9LuzS
# mwCKrB2NO4Bo/tBZmCbO4O2ufyguwp7gC0vICNEyu4P6IzzZ/9KMu/dDI9/nw1oF
# Yn5wLOUrsj1j6siugSBrQ4nIfl+wGt0ZvZ90QQqvuY4J03ShL7BUdsGQT5TshmH/
# 2xEvkgMwzjC3iw9dRLNDHSNQzZHXL537/M2xwafEDsTvQD4ZOgLUMalpoEn5deGb
# 6GjkagyP6+SxIXuGZ1h+fx/oK+QUshbWgaHK2jCQa+5vdcCwNiayCDv/vb5/bBMY
# 38ZtpHlJrYt/YYcFaPfUcONCleieu5tLsuK2QT3nr6caKMmtYbCgQRgZTu1Hm2GV
# 7T4LYVrqPnqYklHNP8lE54CLKUJy93my3YTqJ+7+fXprAgMBAAGjggGLMIIBhzAO
# BgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEF
# BQcDCDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgw
# FoAUuhbZbU2FL3MpdpovdYxqII+eyG8wHQYDVR0OBBYEFI1kt4kh/lZYRIRhp+pv
# HDaP3a8NMFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5j
# cmwwgZAGCCsGAQUFBwEBBIGDMIGAMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5k
# aWdpY2VydC5jb20wWAYIKwYBBQUHMAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdD
# QS5jcnQwDQYJKoZIhvcNAQELBQADggIBAA0tI3Sm0fX46kuZPwHk9gzkrxad2bOM
# l4IpnENvAS2rOLVwEb+EGYs/XeWGT76TOt4qOVo5TtiEWaW8G5iq6Gzv0UhpGThb
# z4k5HXBw2U7fIyJs1d/2WcuhwupMdsqh3KErlribVakaa33R9QIJT4LWpXOIxJiA
# 3+5JlbezzMWn7g7h7x44ip/vEckxSli23zh8y/pc9+RTv24KfH7X3pjVKWWJD6Kc
# wGX0ASJlx+pedKZbNZJQfPQXpodkTz5GiRZjIGvL8nvQNeNKcEiptucdYL0EIhUl
# cAZyqUQ7aUcR0+7px6A+TxC5MDbk86ppCaiLfmSiZZQR+24y8fW7OK3NwJMR1TJ4
# Sks3KkzzXNy2hcC7cDBVeNaY/lRtf3GpSBp43UZ3Lht6wDOK+EoojBKoc88t+dMj
# 8p4Z4A2UKKDr2xpRoJWCjihrpM6ddt6pc6pIallDrl/q+A8GQp3fBmiW/iqgdFtj
# Zt5rLLh4qk1wbfAs8QcVfjW05rUMopml1xVrNQ6F1uAszOAMJLh8UgsemXzvyMjF
# jFhpr6s94c/MfRWuFL+Kcd/Kl7HYR+ocheBFThIcFClYzG/Tf8u+wQ5KbyCcrtlz
# MlkI5y2SoRoR/jKYpl0rl+CL05zMbbUNrkdjOEcXW28T2moQbh9Jt0RbtAgKh1pZ
# BHYRoad3AhMcMYIGTDCCBkgCAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UE
# AxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQCboq
# a7YdhGGpWisLVohBRjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAA
# oQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4w
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU93ZOjqYx/TDB4ACrabolOGuz
# 3NowDQYJKoZIhvcNAQEBBQAEggIApXY9dfB4KGLCskL04c8lJVhvwD2lQve6PKJx
# Mfq6IrVgJRahZKjawad4PvJgwLGp5dc8pC/KA5mhOoc1hL6iwXVMhYG7QnpBANBH
# rTa22+SglkCZBSa23RkNhZRvVnCH1It+a2/tI+PGSRkHeTwZV65pApmw8upWLAVX
# f83uF5Kk2CrNz9rQxEuSEKLQCt2YbrNlm/LANYrjMnXBC1k3Tud94xgcI8UghFt+
# DDmqg7ZYudZD4/B37jroRUof1PGwzxb+lzWmrRlUt06npCfkMpPwsLadq5N1u1Br
# dSRnIUiNCPxZ8jzP1PJqhwLGARQT27p0eD1oSHI3h56CqvEGTmGfIg03b2xp8spU
# c1wFPHsojtF8o6itfmkjDYFWwqklxK8VqeRpG6mS5i4KIeNp3uHqPr+APplVI8/H
# 0midQEtktMjurUBgWUACY8T6Qxnp8BNVlodP8N+9NBCaDDiWPDFv3HPisaj2Q0ZZ
# 3eNPArvN0qKerVmmRpt4KakUoK9wlTku8QMyvC3mMNU4+Jy2/zjQnXRV2wG4p8eY
# cAlyiU/KJ3FM4mEhKGyUd9dRT/O88rJ1IiImyocZyl3sdLSXmTS0E3kllmqr1L/s
# nOXTa7TuKUOnHEd9bCZMnWC2BoPWgEWejCrlJCWrWhC0JpJwDNqveHCf/Uoc8CBP
# kU5H+KahggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQG
# EwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0
# IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhAKekqI
# nsmZQpAGYzhNhpedMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjIwNjA3MTc0NTMxWjAvBgkqhkiG9w0B
# CQQxIgQghviA6EzmKpBFAK9nnO5vckO0Ygc+sATb7LaM6YDwWQYwDQYJKoZIhvcN
# AQEBBQAEggIALlcq0pj9gOV0m4UVB1XjUCMuAikL3mIX3cpb+qUm58Djk1bHr6Iu
# 57hi2NzKCWVFLoF1LLjlaX7WBuB6Xl+Qm7Yg/XuLcOWTT8UeYmQuPtI1Krvckv9d
# v+5MYzXbhkGU62GEtC3OXhIusG8079/PbrJ8QBKjIs1my2mbdU2FARME1BqN3Cl8
# iuhfjHpF93nqxZE9yBe50nXrGY0Sj7NDi6vO8b/cHpC5AUN35kKMMWBqaO442fEg
# UipmsdXcILvd7PQGkYnIaJHkeeCD5U5/WV8IOkLWK+iXNfvcZyaTxDxeIbhS6Mf4
# fZTsGL/d9UeN0v/RN5tmaOSbcbVjVorwSvbdRjg7wUyij+yxko5OLyymp2TO8E5t
# GUbriCFYQIYC7PaXopkPca5MU0RWDjVPcuhAgggcmzy2uPZ9BsstdbvdDTGQrwcn
# GRjBGvubxM9F2VxEUxowBwvQpp5PHeHJBkyDMx08o6bo+YhPMj8vGYfU5fEOp+tn
# /yP6bymhWxnyZZMcFFbM8XP2/LTe6U9cSn/+RkkCWttG5Y743Tdk9Lo54li9nUkj
# +hAeIx7fE26T2Pz2VWLRa3Zv9ZnfHBGjKxySKo3xL2No4p7R51lRNthEZOsvIKkh
# w/ZIXj/fBvjdFkFnG2U1ha5DgK77JDQ7sqpPCTamzSWwaBGEmrkCZvo=
# SIG # End signature block
