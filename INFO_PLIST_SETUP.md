# Info.plist Configuration for Multipeer Connectivity

To enable Multipeer Connectivity, you need to add the following entries to your app's Info.plist:

## Required Permissions

1. **Local Network Usage Description**
   - Key: `NSLocalNetworkUsageDescription` 
   - Value: `This app uses local network to communicate with rescue robot devices for real-time data visualization.`

2. **Bonjour Services**
   - Key: `NSBonjourServices`
   - Type: Array
   - Add two items:
     - `_rescue-robot._tcp`
     - `_rescue-robot._udp`

## Adding via Xcode

1. Open your target settings in Xcode
2. Go to the Info tab
3. Add a new row for "Privacy - Local Network Usage Description"
4. Set the value to the description above
5. Add another row for "Bonjour services"
6. Add the two service items listed above

## Service Type Notes

- Service type must be 1-15 characters
- Can only contain ASCII lowercase letters, numbers, and hyphens
- We use "rescue-robot" which matches our MultipeerConnectivity serviceType

## Network Requirements

- Both devices need WiFi and Bluetooth enabled
- Devices should be nearby (same room recommended)  
- No internet connection required
- Uses Bonjour protocol for device discovery

## Testing

After adding these configurations:
1. Run the app on an iPhone (acts as robot)
2. Run the app on an iPad (acts as controller)
3. On iPad, go to Connection tab and tap "Find Robots"
4. The iPhone should appear in the discovery list
5. Tap Connect to establish connection

The connection status will be shown in:
- iPhone: Bottom status button showing "Controllers: X"
- iPad: Connection status in all tabs