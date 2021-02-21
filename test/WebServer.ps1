
Class RestCollection {

}

$Collections = @{
    'drop' = [pscustomobject]@{
        Path = 'drop'
        CollectionMethods = @('GET','HEAD')
        ItemMethods = @('GET','POST','PATCH','DELETE','HEAD')
        Extension = '.json'
        ContentType = 'application/json'
        ETagCheck = $true
        Validate = {

        }
        Index = {

        }
    }
}
<#

#>
Function Receive-RestRequest ([RestCollection[]]$Collections, [string]$CollectionName, [string]$ItemId) {
    process {
        [System.Net.HttpListenerContext]$context = $_

        $result = $null

        try {
            if (-not $Collections.ContainsKey($Match.collection)) {
                throw 404
            }

            $collection = $Collections[$Match.collection]
            $itemid = $Match.itemid

            if ($itemid) {
                if (-not $collection.ItemMethods.ContainsKey($context.Request.HttpMethod)) {
                    throw 405
                }

                $file = Get-Item -Path ([Path]::Combine($collection.Path, "$itemid$($collection.Extension)")) -ErrorAction SilentlyContinue

                if (-not $file) {
                    throw 404
                }

                if ($context.Request.HttpMethod -eq 'GET' -or $context.Request.HttpMethod -eq 'HEAD') {
                    $context.Response.ContentType = $collection.ContentType
                    $context.Response.ContentLength64 = $file.Length

                    $context.Response.AddHeader('ETag', $file.LastWriteTimeUtc.Ticks)

                    if ($context.Request.HttpMethod -eq 'GET') {
                        $result = $file | Get-Content -Raw
                    }
                } elseif ($context.Request.HttpMethod -eq 'DELETE') {
                    $file | Remove-Item
                } elseif ($context.Request.HttpMethod -eq 'POST' -or $context.Request.HttpMethod -eq 'PATCH') {
                    $tmp = "$($file.FullName).tmp"

                    [IO.FileStream]$target = $null
                    
                    try {
                        $target = [IO.File]::Open($tmp, [IO.FileMode]::Truncate, [IO.FileAccess]::Write, [IO.FileShare]::None)
                    } catch {
                        throw 409
                    }

                    if ($context.Request.HttpMethod -eq 'POST') {
                        $context.Request.InputStream.CopyTo($target)
                    } elseif ($context.Request.HttpMethod -eq 'PATCH') {
                        $body = [System.IO.MemoryStream]::new($_.Request.ContentLength64)

                        $context.Request.InputStream.CopyTo($body)
                        
                        $before = $file | Get-Content | ConvertFrom-Json

                        $patch = [Text.Encoding]::UTF8.GetString($body.ToArray()) | ConvertFrom-Json

                        # TODO: Depth
                        $patch.PSObject.Properties | ForEach-Object {
                            $before.$($_.Name) = $_.Value
                        }

                        $after = $before | ConvertTo-Json -Compress

                        $buffer = [System.IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($after))

                        $buffer.CopyTo($target)
                    }

                    $target.Flush()
                    
                    [IO.File]::Move($tmp, $file.FullName, $true)
                } else {
                    throw 405
                }
            } else {
                if (-not $collection.CollectionMethods.ContainsKey($context.Request.HttpMethod)) {
                    throw 405
                }

                $items = Get-ChildItem $collection.Path -File -Recurse -Filter "*.$($collection.Extension)"

                $itemIds = $items | ForEach-Object {
                    [IO.Path]::GetFileNameWithoutExtension($_.FullName.Replace("$($collection.Path)\", ''))
                }
                
                if ($context.Request.HttpMethod -eq 'GET') {
                    $itemIds
                } elseif ($context.Request.HttpMethod -eq 'HEAD') {

                }
            }
        } catch {
            $result = $_
        }

        $result
    }
}

Receive-HttpListener | ForEach-Object {
    [System.Net.HttpListenerContext]$context = $_
    
    try {
        if ($context.Request.HttpMethod -eq 'OPTIONS') {
            throw 405
        } elseif ($context.Request.RawUrl -eq '/api') {
            if ($context.Request.HttpMethod -eq 'GET') {
                @('v1')
            } else {
                throw 405
            }
        } elseif ($context.Request.RawUrl -eq '/api/v1') {
            if ($context.Request.HttpMethod -eq 'GET') {
                $Collections.Keys
            } else {
                throw 405
            }
        } elseif ($context.Request.RawUrl -match '\/api\/v1\/db\/(?<collection>[^\/]+)(?:/(?<itemid>[^\/]+))?') {
            $context | Receive-RestRequest -Collections $Collections -CollectionName $Match.collection -ItemID $Match.itemid
        } elseif ($context.Request.RawUrl -match '\/api\/v1\/watch') {
            $socket = $context | Connect-HttpListenerWebSocket
            
            
        } else {
            throw 404
        }
    } catch {
        $result = $_
    }
    
    $context | Add-Member -NotePropertyName Result -NotePropertyValue $result -PassThru
} | Send-HttpListener

