/**
 * Author: PavanVarma Pinnamaraju
 * Created Date: 20-03-2024
 * Description: Test class for ImportPartController class.
 *              This class tests the functionality of the ImportPartController class.
 **/
@isTest
private class TestImportPartController {
    // Define constants for test data
    public static final String PART_SETTING_NAME = 'Part_Settings';
    public static final String HIGH_VOLUME_ACCOUNT = 'High Volume';
    public static final String LOW_VOLUME_ACCOUNT = 'Low Volume';
    public static final String PART_NAME = 'New part';
    public static final String PART_NUMBER = '123';
    
    /**
     * Author: PavanVarma Pinnamaraju
     * Created Date: 20-03-2024
     * Description: Test data setup method.
     *              This method creates test data required for the test methods.
     **/
    @testSetup
    static void setupTestData() {
        User standardUser = TestFactoryClass.createUser('Standard User');
        
        User stdUser = TestFactoryClass.getUser('Standard User');
        
        System.runAs(stdUser) {
            // Create High Volume Account
            Account highVolumeAccount = TestFactoryClass.createAccount(HIGH_VOLUME_ACCOUNT);
            
            // Create Low Volume Account
            Account lowVolumeAccount = TestFactoryClass.createAccount(LOW_VOLUME_ACCOUNT);
            
            // Create Part Record
            SQX_Part__c partRecord = TestFactoryClass.createPart(PART_NAME, PART_NUMBER);
        }
    }
    
    /**
     * Author: Author: PavanVarma Pinnamaraju
     * Created Date: 20-03-2024
     * Description: Test method to verify the SyncParts method.
     *              This method tests the behavior of the SyncParts method.
     *              It verifies that parts are synced correctly based on mock HTTP response.
     **/
    @isTest
    static void testSyncParts() {
        User stdUser = TestFactoryClass.getUser('Standard User');
        
        System.runAs(stdUser) {
            // Mocking HTTP response
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
            
            // Start test
            Test.startTest();
            
            // Call the method to test
            ImportPartController.ResponseWrapper result = ImportPartController.SyncParts();
            
            // End test
            Test.stopTest();
            
            // Query created accounts
            Account highVolumeAccount = [SELECT Id, Name FROM Account WHERE Name =: HIGH_VOLUME_ACCOUNT];
            Account lowVolumeAccount = [SELECT Id, Name FROM Account WHERE Name =: LOW_VOLUME_ACCOUNT];
            
            // Verify that new SQX_Part__c records are created
            List<SQX_Part__c> newParts = [SELECT Name, Part_Number__c, Active__c, Related_Account__c 
                                          FROM SQX_Part__c 
                                          WHERE Part_Number__c IN ('123', '456')];
            // Assert the size of new parts list
            System.assertEquals(2, newParts.size());
            
            // Loop through new parts and assert their fields
            for (SQX_Part__c part : newParts) {
                if (part.Part_Number__c == '123') {
                    System.assertEquals('Mock Part 1', part.Name, 'Expected Mock Part 1 but actual is '+part.Name);
                    System.assertEquals(true, part.Active__c, 'Expected true but actual is '+part.Active__c);
                    System.assertEquals(highVolumeAccount.Id, part.Related_Account__c, 'Expected '+highVolumeAccount.Id+' but actual is '+part.Related_Account__c);
                } else if (part.Part_Number__c == '456') {
                    System.assertEquals('Mock Part 2', part.Name, 'Expected Mock Part 1 but actual is '+part.Name);
                    System.assertEquals(true, part.Active__c, 'Expected true but actual is '+part.Active__c);
                    System.assertEquals(lowVolumeAccount.Id, part.Related_Account__c, 'Expected '+lowVolumeAccount.Id+' but actual is '+part.Related_Account__c);
                }
            }
        }
    }
    
    /**
     * Inner class to mock HTTP callout response
     **/
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        /**
         * Author: PavanVarma Pinnamaraju
         * Created Date: 20-03-2024
         * Description: Method to generate mock HTTP response.
         *              This method returns a fake HTTPResponse with predefined body and status code.
         **/
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"_id":"123","Part Name":"Mock Part 1","Total Quantity Shipped":50},' +
                        '{"_id":"456","Part Name":"Mock Part 2","Total Quantity Shipped":99}]');
            res.setStatusCode(200);
            return res;
        }
    }
}