/*
AccountHelper Overview

The 'AccountHelper' class is designed to provide helper methods that assist in performing specific operations on Account records. 
This class is intended to modularize the logic used in the 'AccountTrigger' to ensure separation of concerns, improve readability, and ease maintenance. 

This class is currently stubbed out. As part of this exercise, you are expected to:
1. Implement the method bodies to carry out the specified operations on Account records.
2. Refactor the 'AccountTrigger' to utilize the methods provided in this 'AccountHelper' class.

Methods:
- 'setTypeProspect(SObject objects)': 
    - Purpose: Update the 'Type' field of the given Account record to 'Prospect' if it's not already set.
    - Note: You'll likely need to adjust the method signature to accept the necessary parameters.

- 'addressCopy()': 
    - Purpose: Copy the shipping address of the Account to its billing address. 
    - Note: You'll likely need to adjust the method signature to accept the necessary parameters.

- 'setRating': 
    - Purpose: Evaluate certain conditions on the Account and assign a rating based on that evaluation. You'll need to define the method's signature and implement its logic.

- 'defaultContact': 
    - Purpose: Create a default contact related to the Account after the Account is inserted. You'll need to define the method's signature and implement its logic.

Remember:
Always ensure that your helper methods are bulk-safe to handle multiple records efficiently. 
*/

public with sharing class AccountHelper {
    
    // Set Type to 'Prospect' if it's not already populated.
    public static void setTypeProspect(List<Account> accounts) {
        for (Account acc : accounts) {
            if (String.isBlank(acc.Type)) {
                acc.Type = 'Prospect';
            }
        }
    }

    // Copy the Shipping Address to Billing Address.
    public static void addressCopy(List<Account> accounts) {
        for (Account acc : accounts) {
            if (acc.ShippingStreet != null) acc.BillingStreet = acc.ShippingStreet;
            if (acc.ShippingCity != null) acc.BillingCity = acc.ShippingCity;
            if (acc.ShippingState != null) acc.BillingState = acc.ShippingState;
            if (acc.ShippingPostalCode != null) acc.BillingPostalCode = acc.ShippingPostalCode;
            if (acc.ShippingCountry != null) acc.BillingCountry = acc.ShippingCountry;
        }
    }

    // Set Rating to 'Hot' if Phone, Website, and Fax are populated.
    public static void setRating (List<Account> accounts) {
        for (Account acc : accounts) {
            if (String.isNotBlank(acc.Phone) &&
                String.isNotBlank(acc.Website) &&
                String.isNotBlank(acc.Fax)) {
                acc.Rating = 'Hot';
            }
        }
    }

    // Create a default Contact for each Account AFTER INSERT.
    public static void defaultContact (List<Account> newAccounts) {
        List<Contact> contactsToInsert = new List<Contact>();
        for (Account acc : newAccounts) {
            Contact con = new Contact(
                LastName = 'DefaultContact',
                Email = 'default@email.com',
                AccountId = acc.Id
            );
            contactsToInsert.add(con);
        }

        if (!contactsToInsert.isEmpty()) {
            insert contactsToInsert;
        }
    }
}