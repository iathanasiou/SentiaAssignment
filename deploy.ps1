param(

 #The subscription id where the template will be deployed.
 [Parameter(Mandatory=$True)]
 [string]
 $subscriptionId,

 #The resource group where the template will be deployed existing or a new resource group.
 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName,

 # If specified it will try to create a new resource group in this location. If not specified, assumes resource group is existing.
 [string]
 $resourceGroupLocation,

 # The deployment name.
 [Parameter(Mandatory=$True)]
 [string]
 $deploymentName,

 #Optional, path to the template file. Defaults to template.json
 [string]
 $templateFilePath = "template.json",
 
 #Optional, path to the parameters file. Defaults to parameters.json.If file is not found, will prompt for parameter values based on template.
 [string]
 $parametersFilePath = "parameters.json",
 
 #Optional, path to the policy file. Defaults to policy.json.
 [string]
 $policyFilePath = "policy.json"
)

<#
Using functions to : Register Resource Providers,
					 Create tags for resource group ,
					 Register policy definition and assign it to resource group level
					 Validate the content of the template
#>
#Register resource providers 
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#Create resource group tags
Function CreateTags {
Param(
        [string]$env,
		[string]$comp
     )
	 
#posible environment values (development , test ,production) switch ?	 
Write-Host "Creating tags for the resource group '$resourceGroupName'";
Write-Host "Please choose a value for environment tag from Test/Development/Production";
$env = Read-Host "environment";
Write-Host "Please enter the name of your company.";
$comp = Read-Host "company";

$Tags = (Get-AzureRmResourceGroup -Name $resourceGroupName).Tags;


		<#if($tags.containsKey("Environment"))
				{$Tags.Remove("Environment");
				}
			else{"applying tag"}	
				$Tags += @{"Environment"="$env"};
				
		if($tags.containsKey("Company"))
				{$Tags.Remove("Company");
				}
				else{"applying tag"} #>
				$Tags += @{"Environment"="$env"; "Company"="$comp"};
	  

Set-AzureRmResourceGroup -Name $resourceGroupName -Tag $Tags;
}

#Apply the policy template to the resource group
Function ApplyPolicy {
 Param(
		[Parameter(Mandatory=$True)]
 		[string]$PolicyName,
		
		[Parameter(Mandatory=$True)]
		[string]$PolicyAssigment
	)

Write-Host "Registering the policy definition and assign it to '$resourceGroupName'";
New-AzureRmPolicyDefinition -Name $PolicyName -Policy $policyFilePath;
New-AzureRmPolicyAssignment -Name $PolicyAssigment -PolicyDefinition (Get-AzureRmPolicyDefinition -Name $PolicyName) -Scope /subscriptions/$subscriptionId/resourceGroups/$resourceGroupName;
}

#Validate the content of the template and parameters files.
Function ValidateTemplate {
	
$dep = (Test-AzureRmResourceGroupDeployment -ResourceGroupName test -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath);

if ($dep.Count -eq '0'){"templates are valid , applying templates";}
	Else{"stopping the deployment, please check the templates for errors ";
		  exit;			
		}
}

#******************************************************************************
# # Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

ValidateTemplate ;

# sign in
Write-Host "Logging in...";
Login-AzureRmAccount;

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.network","microsoft.storage");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

#Create the tags
CreateTags;

# Start the deployment
Write-Host "Starting deployment...";
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;

#ApplyPolicy;

Write-Host "Deployment was succesful";