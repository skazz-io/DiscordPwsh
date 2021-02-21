using module .\UserTypes.psm1

<# https://discord.com/developers/docs/interactions/slash-commands#data-models-and-types #>

<#

#>
enum ApplicationCommandOptionType
{
    SUB_COMMAND	= 1
    SUB_COMMAND_GROUP	= 2
    STRING	= 3
    INTEGER	= 4
    BOOLEAN	= 5
    USER	= 6
    CHANNEL	= 7
    ROLE	= 8
}
<#

.DESCRIPTION
If you specify choices for an option, they are the only valid values for a user to pick

.PARAMETER name
1-100 character choice name

.PARAMETER value
value of the choice (string or int)

#>
class ApplicationCommandOptionChoice
{
    [ValidateNotNullOrEmpty()][string]$name
    # TODO: This should be int or string, maybe custom type or if numeric at runtime convert to integer
    [ValidateNotNullOrEmpty()][string]$value
}
<#

.DESCRIPTION
You can specify a maximum of 10 choices per option.

#>
class ApplicationCommandOption
{
    [ValidateNotNullOrEmpty()][ApplicationCommandOptionType]$type
    [ValidateNotNullOrEmpty()][string]$name
    [ValidateNotNullOrEmpty()][string]$description
    [Nullable[bool]]$default
    [Nullable[bool]]$required
    [ApplicationCommandOptionChoice[]]$choices
    [ApplicationCommandOption[]]$options
}
<#

.DESCRIPTION

#>
class ApplicationCommand
{
    [ValidateNotNullOrEmpty()][UInt64]$id
    [ValidateNotNullOrEmpty()][UInt64]$application_id
    [ValidateNotNullOrEmpty()][string]$name
    [ValidateNotNullOrEmpty()][string]$description
    [ApplicationCommandOption[]]$options
}
<#

.DESCRIPTION

#>
class ApplicationCommandInteractionDataOption {
    [ValidateNotNullOrEmpty()][string]$name
    [string]$value
    [ApplicationCommandInteractionDataOption[]]$options
}
<#

.DESCRIPTION

#>
class ApplicationCommandInteractionData {
    [ValidateNotNullOrEmpty()][UInt64]$id
    [ValidateNotNullOrEmpty()][string]$name
    [ApplicationCommandInteractionDataOption[]]$options
}
<#

.DESCRIPTION

#>
Class DiscordRoleTag {
    [Nullable[UInt64]]$bot_id
    [Nullable[UInt64]]$integration_id
    [Nullable[bool]]$premium_subscriber
}
<#

.DESCRIPTION

#>
Class DiscordRole {
    [ValidateNotNullOrEmpty()][UInt64]$id
    [ValidateNotNullOrEmpty()][string]$name
    [ValidateNotNullOrEmpty()][UInt64]$color
    [ValidateNotNullOrEmpty()][bool]$hoist
    [ValidateNotNullOrEmpty()][Int32]$position
    [ValidateNotNullOrEmpty()][string]$permissions
    [ValidateNotNullOrEmpty()][bool]$managed
    [ValidateNotNullOrEmpty()][bool]$mentionable
    [DiscordRoleTag[]]$tags
}
<#

.DESCRIPTION

#>
Class GuildMember {
    [User]$user
    [ValidateNotNullOrEmpty()][string]$nick
    [ValidateNotNullOrEmpty()][UInt64[]]$roles
    [ValidateNotNullOrEmpty()][DateTime]$joined_at
    [Nullable[DateTime]]$premium_since # ISO8601
    [bool]$deaf
    [bool]$mute
    [Nullable[bool]]$pending
}
<#

.DESCRIPTION

#>
enum InteractionType
{
    Ping = 1
    ApplicationCommand = 2
}
<#

.DESCRIPTION

#>
class Interaction
{
    [ValidateNotNullOrEmpty()][UInt64]$id
    [ValidateNotNullOrEmpty()][InteractionType]$type
    [ApplicationCommandInteractionData]$data
    [ValidateNotNullOrEmpty()][UInt64]$guild_id
    [ValidateNotNullOrEmpty()][UInt64]$channel_id
    [ValidateNotNullOrEmpty()][GuildMember]$member
    [ValidateNotNullOrEmpty()][string]$token
    [ValidateNotNullOrEmpty()][int]$version
}
<#

.DESCRIPTION

#>
enum InteractionResponseType
{
    <# ACK a Ping #>
    Pong = 1
    <# ACK a command without sending a message, eating the user's input #>
    Acknowledge = 2
    <# respond with a message, eating the user's input #>
    ChannelMessage = 3
    <# respond with a message, showing the user's input #>
    ChannelMessageWithSource = 4
    <# ACK a command without sending a message, showing the user's input #>
    AcknowledgeWithSource = 5
}
<#

.DESCRIPTION

#>
class InteractionApplicationCommandCallbackData {
    [Nullable[bool]]$tts
    [ValidateNotNullOrEmpty()][string]$content
    [object]$embeds
    [object]$mentions
}
<#

.DESCRIPTION

#>
class InteractionResponse {
    [ValidateNotNullOrEmpty()][InteractionResponseType]$type
    [ValidateNotNullOrEmpty()][InteractionApplicationCommandCallbackData[]]$data
}
<#

.DESCRIPTION

#>
class InteractionResponseCommand {
    [Interaction]$Interaction
    [InteractionResponseType]$InteractionResponse
}