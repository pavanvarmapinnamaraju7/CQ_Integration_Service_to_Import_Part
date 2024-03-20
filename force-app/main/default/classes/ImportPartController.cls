/**
 * Author: PavanVarma Pinnamaraju
 * Created Date: 20-03-2024
 * Description: This class will initiate the parts sync process
**/
public class ImportPartController {

    // Constants defining keys and messages
    public static final String PART_SETTING_NAME = 'Part_Settings';
    public static final String HIGH_VOLUME_ACCOUNT = 'High Volume';
    public static final String LOW_VOLUME_ACCOUNT = 'Low Volume';
    public static final String NO_CONFIGURATION_MESSAGE = 'No Configuration Found, Please set up the configuration';
    public static final String RESPONSE_PART_ID = '_id';
    public static final String RESPONSE_PART_NAME = 'Part Name';
    public static final String RESPONSE_TOTAL_QUANTITY_SHIPPED = 'Total Quantity Shipped';

    /**
     * Author: PavanVarma Pinnamaraju
     * Created Date: 20-03-2024
     * Description: This method will get a response from an external system and sync with the parts.
     * Returns:
     *     ResponseWrapper - This will return statusCode and responseMessage.
     **/
    @AuraEnabled
    public static ResponseWrapper SyncParts() {
        // Initialize response wrapper
        ResponseWrapper rw = new ResponseWrapper(); 
        try {
            // Retrieve configuration settings
            List<Part_Settings__mdt> partSetting = [SELECT Api_Key__c,
                                                    Content_Type__c,
                                                    End_Point__c
                                                    FROM Part_Settings__mdt
                                                    WHERE DeveloperName =: PART_SETTING_NAME];
            
            // Configuration Check
            if (!partSetting.isEmpty() && (partSetting[0].Content_Type__c != null && partSetting[0].Api_Key__c != null && partSetting[0].End_Point__c != null)) {
                // Prepare HTTP request
                HttpRequest request = new HttpRequest();
                request.setMethod('GET');
                request.setHeader('Content-type', partSetting[0].Content_Type__c);
                request.setHeader('x-api-key', partSetting[0].Api_Key__c);
                request.setEndpoint(partSetting[0].End_Point__c);
                
                // Send HTTP request
                HTTP http = new HTTP();
                HTTPResponse response = http.send(request);
                // Get status code
                if (response.getStatusCode() == 200) {
                    // Process response data
                    String partsListFromResponse = response.getBody();
                    List<Object> wrapperClassList = (List<Object>) JSON.deserializeUntyped(partsListFromResponse);
                    
                    Set<String> partIdListFromResponse = new Set<String>();
                    
                    // Extract part IDs from response
                    if (!wrapperClassList.isEmpty()) {
                        for (Object obj : wrapperClassList) {
                            Map<String, Object> partData = (Map<String, Object>) obj;
                            partIdListFromResponse.add((String) partData.get(RESPONSE_PART_ID));
                        }
                    }
                    List<SQX_Part__c> partsList = new List<SQX_Part__c>();
                    
                    // Retrieve accounts with specified names
                    List<Account> AccountList = [SELECT Id, Name FROM Account WHERE Name =: HIGH_VOLUME_ACCOUNT OR Name =: LOW_VOLUME_ACCOUNT];
                    
                    Map<String, Id> accountVolumeMap = new Map<String, Id>();
                    
                    // Create map of account names to IDs
                    if (!AccountList.isEmpty()) {
                        for (Account acc : AccountList) {
                            accountVolumeMap.put(acc.Name, acc.Id);
                        }
                    }
                    
                    // Query existing parts based on IDs from response
                    if (!partIdListFromResponse.isEmpty()) {
                        partsList = [SELECT Id, Name, Active__c, Part_Number__c FROM SQX_Part__c WHERE Part_Number__c IN: partIdListFromResponse];
                    }
                    Map<String, String> partmap = new Map<String, String>();
                    if (!partsList.isEmpty()) {
                        for (SQX_Part__c pr : partsList) {
                            partmap.put(pr.Part_Number__c, pr.Id);
                        }
                    }
                    
                    List<SQX_Part__c> newPartsList = new List<SQX_Part__c>();
                    
                    // Create new parts based on response data
                    if (!wrapperClassList.isEmpty()) {
                        for (Object obj : wrapperClassList) {
                            Map<String, Object> wrapper = (Map<String, Object>) obj;
                            SQX_Part__c part = new SQX_Part__c();
                            if (partmap.get((String) wrapper.get(RESPONSE_PART_ID)) != null) {
                                part.Id = partmap.get((String) wrapper.get(RESPONSE_PART_ID));
                            }
                            part.Name = (String) wrapper.get(RESPONSE_PART_NAME);
                            part.Part_Number__c = (String) wrapper.get(RESPONSE_PART_ID);
                            part.Active__c = true;
                            Integer totalQuantityShipped = (Integer) wrapper.get(RESPONSE_TOTAL_QUANTITY_SHIPPED);
                            // Determine account based on quantity shipped
                            if (totalQuantityShipped < 99) {
                                if (accountVolumeMap.get(HIGH_VOLUME_ACCOUNT) != null) {
                                    part.Related_Account__c = accountVolumeMap.get(HIGH_VOLUME_ACCOUNT);
                                }
                            } else if (totalQuantityShipped >= 99) {
                                if (accountVolumeMap.get(LOW_VOLUME_ACCOUNT) != null) {
                                    part.Related_Account__c = accountVolumeMap.get(LOW_VOLUME_ACCOUNT);
                                }
                            }
                            newPartsList.add(part);
                        }
                    }
                    
                    // Upsert new parts
                    if (!newPartsList.isEmpty()) {
                        upsert newPartsList;
                    }
                    rw.statusCode = response.getStatusCode(); 
                    rw.responseMessage = 'Success';
                    
                } else {
                    // Set status code and message from response
                    rw.statusCode = response.getStatusCode(); 
                    rw.responseMessage = response.getStatus(); 
                }
                
            } else {
                // Set status code and message for missing configuration
                rw.statusCode = null; 
                rw.responseMessage = NO_CONFIGURATION_MESSAGE; 
            }
            
        }
        // Catch any exceptions and set response message accordingly
        catch (Exception ex) {
            rw.statusCode = null; 
            rw.responseMessage = ex.getMessage(); 
        }
        
        return rw;     
    }
    
    // This wrapper class will store data from the response.
    public class ResponseWrapper {
        @AuraEnabled public Integer statusCode {get; set;} // Status code of the response
        @AuraEnabled public String responseMessage {get; set;} // Response message
    }
}