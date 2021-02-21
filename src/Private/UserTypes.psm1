
<#

.DESCRIPTION

#>
Class User {
    [ValidateNotNullOrEmpty()][UInt64]$id
    [ValidateNotNullOrEmpty()][string]$username
    [ValidateNotNullOrEmpty()][string]$discriminator
    [string]$avatar
    [Nullable[bool]]$bot
    [Nullable[bool]]$system
    [Nullable[bool]]$mfa_enabled
    [string]$locale
    [Nullable[bool]]$verified
    [string]$email
    [Nullable[int]]$flags
    [Nullable[int]]$premium_type
    [Nullable[int]]$public_flags
}