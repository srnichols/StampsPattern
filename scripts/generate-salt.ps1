# Generates a random 6-character alphanumeric salt for use in resource names
$chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
$rand = -join ((1..6) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
Write-Output $rand
