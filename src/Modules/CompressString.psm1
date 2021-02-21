
Function Compress-String {
    process {
        $buffer = [Text.Encoding]::UTF8.GetBytes($_)
        $ms = [IO.MemoryStream]::new()
        $gzip = [IO.Compression.GZipStream]::new($ms, [IO.Compression.CompressionMode]::Compress, $true)
        $gzip.Write($buffer, 0, $buffer.Length)
        $gzip.Flush()
        $gzip.Close()
        [Convert]::ToBase64String($ms.ToArray())
    }
}

Function Expand-String {
    process {
        [IO.StreamReader]::new([IO.Compression.GZipStream]::new([IO.MemoryStream]::new([Convert]::FromBase64String($_)), [IO.Compression.CompressionMode]::Decompress, $false)).ReadToEnd()
    }
}
