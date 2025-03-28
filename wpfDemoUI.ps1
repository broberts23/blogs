# Load required WPF assembly
Add-Type -AssemblyName PresentationFramework

# Define the XAML layout.
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Multi-Input - Authentication Demo" Height="500" Width="500">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Inputs container -->
            <RowDefinition Height="Auto"/> <!-- Password Field -->
            <RowDefinition Height="Auto"/> <!-- Button Panel -->
            <RowDefinition Height="Auto"/> <!-- ProgressBar -->
            <RowDefinition Height="*"/>    <!-- Result TextBlock -->
        </Grid.RowDefinitions>
        <!-- StackPanel for Input Fields -->
        <StackPanel Grid.Row="0" Orientation="Vertical">
            <!-- Input 1: ServiceNow Case Validation -->
            <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                <Label Content="Case ID:" Width="120"/>
                <TextBox Name="Input1" Width="330" Height="25"/>
            </StackPanel>
            <!-- Input 2: Email Validation -->
            <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                <Label Content="Email:" Width="120"/>
                <TextBox Name="Input2" Width="330" Height="25"/>
            </StackPanel>
            <!-- Input 3: Email Validation -->
            <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                <Label Content="User ID:" Width="120"/>
                <TextBox Name="Input3" Width="330" Height="25"/>
            </StackPanel>
            <!-- Input 4: Email Validation -->
            <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                <Label Content="Input N:" Width="120"/>
                <TextBox Name="Input4" Width="330" Height="25"/>
            </StackPanel>
        </StackPanel>
        <!-- Password Field for Client Secret -->
        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,10,0,10">
            <Label Content="Client Secret:" Width="120"/>
            <!-- Using PasswordBox ensures the text is hidden -->
            <PasswordBox Name="PasswordInput" Width="330" Height="25"/>
        </StackPanel>
        <!-- Button Panel for Submit and Quit -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Left" Margin="0,10,0,10">
            <Button Name="SubmitButton" Content="Submit" Width="100" Height="30" Margin="0,0,10,0"/>
            <Button Name="QuitButton" Content="Quit" Width="100" Height="30"/>
        </StackPanel>
        <!-- Progress Bar for Visual Feedback -->
        <ProgressBar Grid.Row="3" Name="ProgressBar" Height="20" Margin="0,10,0,10" Minimum="0" Maximum="100" Value="0"/>
        <!-- Result TextBlock to display output messages -->
        <TextBlock Grid.Row="4" Name="ResultTextBlock" Text="" FontSize="14" Foreground="Blue" TextWrapping="Wrap"/>
    </Grid>
</Window>
"@

# Load the XAML and create the window.
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Retrieve controls by their names.
$Input1 = $window.FindName("Input1")
$Input2 = $window.FindName("Input2")
$Input3 = $window.FindName("Input3")
$Input4 = $window.FindName("Input4")
$PasswordInput = $window.FindName("PasswordInput") # PasswordBox control
$SubmitButton = $window.FindName("SubmitButton")
$QuitButton = $window.FindName("QuitButton")
$ProgressBar = $window.FindName("ProgressBar")
$ResultTextBlock = $window.FindName("ResultTextBlock")

# Define regex patterns:
# For Input 1: Match ServiceNow case numbers starting with RITM or INC followed by exactly 7 digits.
$regexPatternCase = '^(RITM|INC)\d{7}$'
# For Inputs 2-4: We'll use an email pattern as an example.
$regexPatternEmail = '^[A-Za-z]+\.[A-Za-z]+@[A-Za-z]+\.com\.au$'


# Attach event handler for the Submit button.
$SubmitButton.Add_Click({
        # Disable the Submit button to prevent multiple clicks.
        $SubmitButton.IsEnabled = $false
    
        # Reset progress and clear results.
        $ProgressBar.Value = 0
        $ResultTextBlock.Text = ""
    
        # Prepare the list of inputs with their specific regex.
        $inputs = @(
            @{ Control = $Input1; Label = "Input 1 (Case)"; Pattern = $regexPatternCase; GetValue = { param($ctrl) $ctrl.Text.Trim() } },
            @{ Control = $Input2; Label = "Input 2"; Pattern = $regexPatternEmail; GetValue = { param($ctrl) $ctrl.Text.Trim() } },
            @{ Control = $Input3; Label = "Input 3"; Pattern = $regexPatternEmail; GetValue = { param($ctrl) $ctrl.Text.Trim() } },
            @{ Control = $Input4; Label = "Input 4"; Pattern = $regexPatternEmail; GetValue = { param($ctrl) $ctrl.Text.Trim() } },
            @{ Control = $window.FindName("PasswordInput"); Label = "Client Secret"; Pattern = $null; GetValue = { param($ctrl) $ctrl.Password.Trim() } }
        )

        # Initialize a variable to store validation failures.
        $validationFailures = @()

        # Validate each input in the list.
        foreach ($i in $inputs) {
            $value = & $i.GetValue $i.Control
    
            if ([string]::IsNullOrWhiteSpace($value)) {
                $validationFailures += "$($i.Label) failure: No value provided."
            }
            elseif ($i.Pattern -and -not [System.Text.RegularExpressions.Regex]::IsMatch($value, $i.Pattern)) {
                $validationFailures += "$($i.Label) failure: '$value' does not match the required pattern."
            }
        }
        # Additionally, validate the password field.
        $passwordValue = $PasswordInput.Password.Trim()
        if ([string]::IsNullOrWhiteSpace($passwordValue)) {
            $validationFailures += "Client Secret failure: No value provided."
        }
    
        # If there are any validation failures, output them and re-enable the button.
        if ($validationFailures.Count -gt 0) {
            $ResultTextBlock.Text = ($validationFailures -join "`n")
            $ResultTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
            $SubmitButton.IsEnabled = $true
            return
        }
    
        # If validation passes, update progress.
        $ProgressBar.Value = 20
        $ResultTextBlock.Text = "All inputs validated. Preparing client secret and submitting data..."
        $ResultTextBlock.Foreground = [System.Windows.Media.Brushes]::Blue
        $window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Render)
    
        # For example, to authenticate a service principal to Azure:
        $tenant = "YOUR_TENANT_ID"
        $appId = "YOUR_SERVICE_PRINCIPAL_APP_ID"
        $secret = $passwordValue
        $scope = "api://your-api-client-id/.default"

        # Construct the token endpoint URL
        $tokenEndpoint = "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token"

        # Define the body for the token request
        $body = @{
            client_id     = $appId
            client_secret = $secret
            scope         = $scope
            grant_type    = "client_credentials"
        }

        # Request the token
        $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body
        $accessToken = $response.access_token

        # Use the access token to call an API
        $headers = @{
            Authorization = "Bearer $accessToken"
        }

        # Example: Call your Azure Function App (update the URL accordingly).
        $functionUrl = "https://<your-function-app-name>.azurewebsites.net/api/CreateAccount?code=<your-function-key>"
        
        # Build a payload including all inputs.
        $payload = @{
            input1 = $Input1.Text.Trim()
            input2 = $Input2.Text.Trim()
            input3 = $Input3.Text.Trim()
            input4 = $Input4.Text.Trim()
        } | ConvertTo-Json
    
        Invoke-WebRequest -Method POST -Uri $functionUrl -Headers $headers -ContentType 'application/json' -Body $payload -UseBasicParsing

        # Simulate further progress.
        $ProgressBar.Value = 40
        $window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Render)
    
        try {
            $ProgressBar.Value = 60
            $response = Invoke-WebRequest -Uri $functionUrl -Method Post -Body $payload -ContentType "application/json"
            $ProgressBar.Value = 80
        
            $resultObj = $response.Content | ConvertFrom-Json
            if ($resultObj.status -eq "success") {
                $ResultTextBlock.Text = "Account created successfully!`nUser ID: $($resultObj.userId)"
                $ResultTextBlock.Foreground = [System.Windows.Media.Brushes]::Green
            }
            else {
                $ResultTextBlock.Text = "Error from Function App: $($resultObj.message)"
                $ResultTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
            }
            $ProgressBar.Value = 100
        }
        catch {
            $ResultTextBlock.Text = "Error submitting to function app: $($_.Exception.Message)"
            $ResultTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
            $ProgressBar.Value = 0
        }
        finally {
            # Re-enable the submit button.
            $SubmitButton.IsEnabled = $true
        }
    })

# Attach event handler for the Quit button to close the window.
$QuitButton.Add_Click({
        $window.Close()
    })

# Optional cleanup on window closing.
$window.Add_Closing({
        Write-Host "Application closing..."
    })

# Show the window modally.
$window.ShowDialog() | Out-Null
