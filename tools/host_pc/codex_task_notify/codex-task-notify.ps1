param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Args
)

python "$PSScriptRoot\main.py" @Args
exit $LASTEXITCODE
