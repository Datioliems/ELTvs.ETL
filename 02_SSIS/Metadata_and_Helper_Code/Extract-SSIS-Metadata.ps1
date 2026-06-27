param(
    [Parameter(Mandatory = $true)]
    [string]$PackagePath,

    [string]$OutputDirectory = (Split-Path -Parent $PackagePath)
)

$ErrorActionPreference = 'Stop'
[xml]$xml = Get-Content -LiteralPath $PackagePath -Raw
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$variables = foreach ($variable in $xml.SelectNodes("//*[local-name()='Variable']")) {
    $valueNode = $variable.SelectSingleNode("./*[local-name()='VariableValue']")
    [pscustomobject]@{
        Namespace = ($variable.Attributes | Where-Object LocalName -eq 'Namespace' | Select-Object -ExpandProperty Value -First 1)
        Name = ($variable.Attributes | Where-Object LocalName -eq 'ObjectName' | Select-Object -ExpandProperty Value -First 1)
        Expression = ($variable.Attributes | Where-Object LocalName -eq 'Expression' | Select-Object -ExpandProperty Value -First 1)
        DataType = if ($valueNode) { $valueNode.GetAttribute('DataType', 'www.microsoft.com/SqlServer/Dts') } else { $null }
        DefaultValue = if ($valueNode -and $valueNode.InnerText.Length -lt 200) { $valueNode.InnerText } else { '<object-or-long-value>' }
    }
}

$variables | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'SSIS_VARIABLES.csv') -NoTypeInformation -Encoding UTF8

$statements = [System.Collections.Generic.List[string]]::new()
$index = 0

foreach ($attribute in $xml.SelectNodes('//@*[local-name()="SqlStatementSource"]')) {
    $index++
    $statements.Add("-- SQL Task statement $index")
    $statements.Add($attribute.Value)
    $statements.Add("`r`nGO`r`n")
}

foreach ($property in $xml.SelectNodes("//*[local-name()='property' and (@name='SqlCommand' or @name='SQLCommand' or @name='CommandText')]")) {
    if (-not [string]::IsNullOrWhiteSpace($property.InnerText)) {
        $index++
        $statements.Add("-- Data Flow SQL statement $index")
        $statements.Add($property.InnerText)
        $statements.Add("`r`nGO`r`n")
    }
}

$statements | Set-Content -LiteralPath (Join-Path $OutputDirectory 'SSIS_EMBEDDED_SQL.sql') -Encoding UTF8

[pscustomobject]@{
    Package = (Resolve-Path -LiteralPath $PackagePath).Path
    Variables = $variables.Count
    SqlStatements = $index
    OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
}
