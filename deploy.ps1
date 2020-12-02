
$releaseName = "<my-awesome-helm-release>"
$newTag = 8

$chartFolder = "chart"
$valuesFile = ".chart/values.yaml"

# Variable declarations
$startTime = $(get-date)

# Find which slot we're currently pointing to in the service
$currentSlot = helm get values --all $releaseName -o json | jq -r '.productionSlot'
if ($currentSlot -eq "blue") {
    $currentSlot = "blue"
    $newSlot = "green"
}
else {
    $currentSlot = "green"
    $newSlot = "blue"
}

write-host("New slot is: $newSlot")

# Find name of the deployment (really just a Value, but we'll use it as deployment identifier)
$labelName = helm get values --all $releaseName -o json | jq -r '.label.name'
$deployment = "$labelName-$newSlot-deployment"
Write-Host("deployment: $deployment")

# Find which tag we're currently live with (to be able to keep that deployment intact)
# --exit-status makes an error exit if value cannot be parsed
$currentTag = helm get values --all $releaseName -o json | jq ".$currentSlot.tag" -r --exit-status

if (-not $? ) {
    Write-Host("❌ Couldn't find a tag for container.tag, aborting")
    exit 1
}

Write-Host("⏳ upgrading helm chart $releaseName")
write-host("installing $releaseName : $newTag in $newSlot slot...")
write-host("   keeping $releaseName : $currentTag in $currentSlot slot")

# upgrade new slot
helm upgrade $releaseName --install $chartFolder --values $valuesFile --set "$newSlot.enabled=true" --set "$newSlot.tag=$newTag" --set "$currentSlot.tag=$currentTag" --set "productionSlot=$currentSlot" --set "stagingSlot=$newSlot" >$null

if ( -not $? ) {
    Write-Host("❌helm upgrade failed, aborting")
    exit 1
}
else {
    Write-Host("✅ helm upgrade done!")
}


# hold on until deployment is up and running
Write-Host("⏳ wait until $releaseName-$newSlot-deployment is done...")
kubectl rollout status deployment/$deployment
Write-Host("✅ rollout done")

# Smoke-test the new deployment
Write-Host("⏳ running smoke test of $newSlot deployment...")

helm test $releaseName --logs

if ( -not $? ) {
    Write-Host("smoke-test failed")
    Write-Host("rolling back $newSlot deployment")
    helm upgrade $releaseName --install $chartFolder --values $valuesFile --set "$newSlot.enabled=false" --set "$newSlot.tag=$newTag" --set "$currentSlot.tag=$currentTag" --set "productionSlot=$currentSlot" --set "stagingSlot=$newSlot" >$null
    Write-Host("roll-back of $newSlot deployment done")
    Write-Host("❌ aborting job")
    exit 1
}
else {
    Write-Host("✅ smoke-test success!")
}

# redirect service to new deployment
Write-Host("⏳ pointing service to $newSlot...")
helm upgrade $releaseName --install $chartFolder --set "productionSlot=$newSlot" --reuse-values >$null 2>&1

if ( -not $? ) {
    Write-Host("❌ redirecting service failed, aborting job")
    exit 1
}
else {
    Write-Host("✅ service redirection done!")
}

Write-Host("⏳ removing previous slot $currentSlot...")
helm upgrade $releaseName --install $chartFolder --set "$currentSlot.enabled=false" --reuse-values >$null 2>&1
Write-Host("✅ $currentSlot removed!")

$elapsedTime = $(get-date) - $startTime
$totalTime = "{0:ss}" -f ([datetime]$elapsedTime.Ticks)

Write-Host("✅ blue-green deploy finished in $totalTime seconds!")
