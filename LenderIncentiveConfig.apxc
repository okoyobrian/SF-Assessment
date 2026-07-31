public class LenderIncentiveConfig {
    // Default Org-Wide Fallbacks (Applied when no Lender Exception exists)
    public static final Decimal DEFAULT_OI_MIN_LOAN = 10000.00;
    public static final Decimal DEFAULT_OI_BASE_RATE = 0.0300; // 3.0%
    public static final Decimal DEFAULT_OI_IMPACT_UPLIFT = 0.0050; // 0.5% per point
    public static final Decimal DEFAULT_FLC_BASE_RATE = 0.1000; // 10.0%
    public static final Decimal DEFAULT_FLC_RETURNING_INC = 0.0200; // 2.0%

    public Id lenderId { get; private set; }
    public Boolean isOIEligible { get; private set; }
    public Boolean isFLCEligible { get; private set; }
    public Decimal oiMinLoan { get; private set; }
    public Decimal oiBaseRate { get; private set; }
    public Decimal oiImpactUplift { get; private set; }
    public Decimal flcBaseRate { get; private set; }
    public Decimal flcReturningInc { get; private set; }

    public Map<String, Decimal> countryMultipliers { get; private set; }
    public Map<String, Decimal> valueChainMultipliers { get; private set; }

    public LenderIncentiveConfig(Id lenderId) {
        this.lenderId = lenderId;
        this.isOIEligible = true;
        this.isFLCEligible = true;
        this.oiMinLoan = DEFAULT_OI_MIN_LOAN;
        this.oiBaseRate = DEFAULT_OI_BASE_RATE;
        this.oiImpactUplift = DEFAULT_OI_IMPACT_UPLIFT;
        this.flcBaseRate = DEFAULT_FLC_BASE_RATE;
        this.flcReturningInc = DEFAULT_FLC_RETURNING_INC;
        this.countryMultipliers = new Map<String, Decimal>();
        this.valueChainMultipliers = new Map<String, Decimal>();
    }

    public void applyException(
        Lender_Exception__c exc, 
        List<Lender_Country_Multiplier__c> cList, 
        List<Lender_Value_Chain_Multiplier__c> vcList
    ) {
        if (exc == null) return;

        // Apply dynamic overrides only if field values are explicitly populated
        if (exc.Is_OI_Eligible__c != null) this.isOIEligible = exc.Is_OI_Eligible__c;
        if (exc.Is_FLC_Eligible__c != null) this.isFLCEligible = exc.Is_FLC_Eligible__c;
        if (exc.OI_Min_Loan_Amount__c != null) this.oiMinLoan = exc.OI_Min_Loan_Amount__c;
        if (exc.OI_Revenue_Base_Rate__c != null) this.oiBaseRate = exc.OI_Revenue_Base_Rate__c;
        if (exc.OI_Impact_Uplift_Per_Point__c != null) this.oiImpactUplift = exc.OI_Impact_Uplift_Per_Point__c;
        if (exc.FLC_Base_Rate__c != null) this.flcBaseRate = exc.FLC_Base_Rate__c;
        if (exc.FLC_Returning_Borrower_Increment__c != null) this.flcReturningInc = exc.FLC_Returning_Borrower_Increment__c;

        if (cList != null) {
            for (Lender_Country_Multiplier__c c : cList) {
                if (String.isNotBlank(c.Country_Code__c) && c.Multiplier__c != null) {
                    this.countryMultipliers.put(c.Country_Code__c.toUpperCase(), c.Multiplier__c);
                }
            }
        }

        if (vcList != null) {
            for (Lender_Value_Chain_Multiplier__c vc : vcList) {
                if (String.isNotBlank(vc.Value_Chain__c) && vc.Multiplier__c != null) {
                    this.valueChainMultipliers.put(vc.Value_Chain__c.toLowerCase(), vc.Multiplier__c);
                }
            }
        }
    }

    public Decimal getCountryMultiplier(String country) {
        if (String.isBlank(country)) return 1.0;
        String key = country.toUpperCase();
        return countryMultipliers.containsKey(key) ? countryMultipliers.get(key) : 1.0;
    }

    public Decimal getValueChainMultiplier(String valueChain) {
        if (String.isBlank(valueChain)) return 1.0;
        String key = valueChain.toLowerCase();
        return valueChainMultipliers.containsKey(key) ? valueChainMultipliers.get(key) : 1.0;
    }
}
