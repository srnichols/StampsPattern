# Generates a random 4-character alphanumeric salt for use in resource names
# Updated to match actual usage in Key Vault naming (take(salt, 4))
$chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
$rand = -join ((1..4) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
Write-Output $rand
