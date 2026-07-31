public class LenderExceptionService {
    // Static in-memory cache to prevent redundant SOQL queries within the same transaction context
    private static Map<Id, LenderIncentiveConfig> cache = new Map<Id, LenderIncentiveConfig>();

    public static Map<Id, LenderIncentiveConfig> getConfigsForLenders(Set<Id> lenderIds) {
        Map<Id, LenderIncentiveConfig> results = new Map<Id, LenderIncentiveConfig>();
        Set<Id> missingIds = new Set<Id>();

        for (Id lid : lenderIds) {
            if (cache.containsKey(lid)) {
                results.put(lid, cache.get(lid));
            } else {
                missingIds.add(lid);
            }
        }

        if (missingIds.isEmpty()) return results;

        // Bulk query active exceptions and child multipliers
        List<Lender_Exception__c> exceptions = [
            SELECT Id, Lender__c, Is_OI_Eligible__c, Is_FLC_Eligible__c, 
                   OI_Min_Loan_Amount__c, OI_Revenue_Base_Rate__c, OI_Impact_Uplift_Per_Point__c,
                   FLC_Base_Rate__c, FLC_Returning_Borrower_Increment__c,
                   (SELECT Country_Code__c, Multiplier__c FROM Lender_Country_Multipliers__r),
                   (SELECT Value_Chain__c, Multiplier__c FROM Lender_Value_Chain_Multipliers__r)
            FROM Lender_Exception__c
            WHERE Lender__c IN :missingIds AND Is_Active__c = true
        ];

        Map<Id, Lender_Exception__c> excMap = new Map<Id, Lender_Exception__c>();
        for (Lender_Exception__c exc : exceptions) {
            excMap.put(exc.Lender__c, exc);
        }

        for (Id lid : missingIds) {
            LenderIncentiveConfig config = new LenderIncentiveConfig(lid);
            if (excMap.containsKey(lid)) {
                Lender_Exception__c exc = excMap.get(lid);
                config.applyException(
                    exc, 
                    exc.Lender_Country_Multipliers__r, 
                    exc.Lender_Value_Chain_Multipliers__r
                );
            }
            cache.put(lid, config);
            results.put(lid, config);
        }

        return results;
    }
}
