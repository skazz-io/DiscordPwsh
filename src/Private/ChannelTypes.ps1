using module .\UserTypes.psm1

<#

#>
Enum ChannelType {
    <# a text channel within a server #>
    GUILD_TEXT = 0
    <# a direct message between users #>
    DM = 1
    <# a voice channel within a server #>
    GUILD_VOICE = 2
    <# a direct message between multiple users #>
    GROUP_DM = 3
    <# an organizational category that contains up to 50 channels #>
    GUILD_CATEGORY = 4
    <# a channel that users can follow and crosspost into their own server #>
    GUILD_NEWS = 5
    <# a channel in which game developers can sell their game on Discord #>
    GUILD_STORE = 6
}
<#

#>
Enum OverwriteType {
    Role = 0
    Member = 1
}
<#
.DESCRIPTION See permissions for more information about the allow and deny fields.
#>
Class Overwrite {
    [uint64]$id
    [OverwriteType]$type
    [string]$allow
    [string]$deny
}
<#
.DESCRIPTION Represents a guild or DM channel within Discord.
#>
Class Channel {
    [uint64]$id
    [ChannelType]$type
    [Nullable[uint64]]$guild_id
    [Nullable[int]]$position
    [Overwrite[]]$permission_overwrites
    [string]$name
    [string]$topic
    [Nullable[bool]]$nsfw
    [Nullable[uint64]]$last_message_id
    [Nullable[int]]$bitrate
    [Nullable[int]]$user_limit
    [Nullable[int]]$rate_limit_per_user
    [User[]]$recipients
    [string]$icon
    [Nullable[uint64]]$owner_id
    [Nullable[uint64]]$application_id
    [Nullable[uint64]]$parent_id
    [Nullable[DateTime]]$last_pin_timestamp
}
<#
.DESCRIPTION Represents a message sent in a channel within Discord.
#>
Class Message {
    
}