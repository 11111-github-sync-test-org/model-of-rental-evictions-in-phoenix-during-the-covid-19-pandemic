; PUMAS: 101, 102, 103, 104 are Mesa, 100, 105, 106, 107 are Gilbert-Chandler, 109, 108 are Tempe, 110, 111, 112 are Scottsdale, and 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 125, 128 is Phoenix.

; *NA   Used to demarcate values or equations that are unclear and need more research. In most cases a random number is used as a placeholder.

extensions[csv]

globals[
  population
  year
  rental-properties
  empty-patches
  month
  ;; Variables used to track model metrics
  average-utility-arrears
  average-rental-arrears
  average-balance-renters
  average-balance-evicted
  count-evicted-from-home
  count-evicted-from-apt
  count-evicted-from-trailer
  count-evicted
  sixty-pct-state-median-income
  eighty-pct-state-median-income
  ;; CAP stands for community assistance program
  cap-maricopa-utility-pot
  cap-mesa-utility-pot
  cap-phx-utility-pot
  cap-maricopa-rental-pot
  cap-mesa-rental-pot
  cap-phx-rental-pot
  cap-maricopa-rental-assist-monthly-apts
  cap-mesa-rental-assist-monthly-apts
  cap-phoenix-rental-assist-monthly-apts
  faith-based-assist-pot
  monthly-evicted-count
  monthly-evicted-count-final
  tracker-rental-assistance
  tracker-utility-assistance
  tracker-faith-based-assistance
  ;;COVID
  evictions-begin-again
  month-incomes-improve
  pause-month
  covid-shock-quantity
  ;New MAG Trackers
  hhs-requesting-appointments-rental
  hhs-getting-appointments-rental
  hhs-requesting-appointments-utility
  hhs-getting-appointments-utility
]

; patches function as rental properties
patches-own[
  rent
  tenant?
  number-of-rooms ; RMSP
  rental-puma
  is-a-rental-property?
  building-type
  township
]

breed [renters renter]

renters-own[
  household-type;HHT
  number-of-persons;NP
  SNAP ; Supplemental Nutrition Assistance Program funds
  PAP ; amount of TANF, Temporary Assistance for Needy Families
  vehicle-number;VEH SB* are we recoding just one or presence absence, Vehicles do not currently factor into the model.
  vehicles-with-lien; Vehicles do not currently factor into the model.
  annual-household-income;HINCP
  monthly-rental-payment;RNTP
  balance ;your bank account
  subsistence-cost
  utility-cost
  rental-arrears; tracks while in a residence - then 0 when evicted, but debt is captured in balance
  utility-arrears; tracks while in a residence - then 0 when evicted, but debt is captured in balance
  residence-type
  puma
  town
  evicted?
  annual-ss-income
  monthly-hh-income
  monthly-hh-ss-income

  ;Information Tracking Variables
  unable-to-pay-utilities-or-rent ;  track the nubmer of cycles that this ocurred
  months-evicted
  previous-rental-location
  months-since-utility-assistance
  months-since-rental-assistance
  income-decreased-by-covid
  income-type ; fixed or variable


]


to Setup
    __clear-all-and-reset-ticks
  ;; Instantiate Rental Households according to PHX metro area ACS Data

  if population-representation-sample > 25 and population-representation-sample < 51
  [resize-world -750 750 -750 750 set-patch-size 0.25]
  if population-representation-sample > 10 and population-representation-sample < 26
  [resize-world -500 500 -500 500 set-patch-size 0.75]
  if population-representation-sample < 11
  [resize-world -250 250 -250 250 set-patch-size 1.5]

  import-pcolors "Data/phx.png"

  Setup-Cities

  Load-Households-and-Rentals

  set rental-properties patches with [is-a-rental-property? = true]
  set empty-patches patches with [is-a-rental-property? = false and pcolor = 0]

  set year 1
  set month 1


  set count-evicted-from-home 0
  set count-evicted-from-apt 0
  set count-evicted-from-trailer 0
  set count-evicted 0
  ; info from https://www.hsd.maricopa.gov/5581/Utility-Assistance
  set sixty-pct-state-median-income (list 0 2061 2695 3329 3964 4558 5232 5351 5800 6500 7000 7500 8000 8250 8500 9000)  ;*SB this needs to be finished with real numbers
  set eighty-pct-state-median-income (list 0 2748 3593 4438 5285 6077 6976 7134 7733 8666 9333 10000 10666 11000 11333 12000)  ;*MAG
  set evictions-begin-again (month-number Evictions-Begin-Again-2021) + 12
  ifelse pause-evictions-April2020 and covid-effects [set pause-month 3][set pause-month 500]


end

to Load-Households-and-Rentals

  ; Read Information from the synthetic population
  ;let population-file "Data/synthetic200Dec17.csv"
  let population-file "Data/syntheticACS20195yr.csv"
  let population-list []
  set population-list csv:from-file population-file
  ; population list looks like this: [[PUMA TYPE BLD NP RNTP SNAP RMSP VEH HINCP TANF weight] [100 female head apartment 1 740 0 3 0 960 0 12] ...

  ;; Remove the column names from the list
  set population-list but-first population-list
  ask patches [set tenant? false set is-a-rental-property? false] ; used to place houses on empty patches

  foreach population-list[ ?1 ->
    let hh-list-entry ?1
    let renters-to-create 1
    let population-weight item 10 hh-list-entry  ; max is currently 115
    ;Note that the command int just eliminates the decimal - it does not round
    set renters-to-create int (population-weight * (population-representation-sample / 100)) ;
    if renters-to-create < 1 [set renters-to-create 1]

    ;eliminate synthetic population households that have no income
    if item 8 hh-list-entry < 0 [ set renters-to-create 0]

    ;Initialize Renters
    create-renters renters-to-create [
      set evicted? false
      set months-evicted 0

      set puma item 0 hh-list-entry
      if puma = 101 or puma = 102 or puma = 103 or puma = 104 [set town "Mesa"]
      if puma = 100 or puma = 105 or puma = 106 or puma = 107 [set town "Gilbert-Chandler"]
      if puma = 108 or puma = 109  [set town "Tempe"]
      if puma = 110 or puma = 111 or puma = 112 [set town "Scottsdale"]
      if puma > 112 [set town "Phoenix"]
      let my-town town
      move-to one-of patches with [is-a-rental-property? = false and township = my-town]
      set previous-rental-location patch-here
      set household-type item 1 hh-list-entry
      set residence-type item 2 hh-list-entry
      if residence-type = "house" [set shape "house"]
      if residence-type = "apartment" [set shape "apartment"]
      if residence-type = "trailer" [set shape "trailer"]

      set number-of-persons item 3 hh-list-entry
      set monthly-rental-payment item 4 hh-list-entry
      let food-stamps  item 5 hh-list-entry
      if food-stamps > 0 [set SNAP determine-SNAP number-of-persons ]

      set vehicle-number  item 7 hh-list-entry
      set vehicles-with-lien 0
      ;ifelse vehicle-number > 0 [ set car-payment (random 50) + 50][set car-payment 0]   ; *NA
      set annual-household-income  item 8 hh-list-entry ; annual amount
      set utility-cost item 13 hh-list-entry
      set pap  item 9 hh-list-entry
      set vehicles-with-lien 0
      set balance random 500 ;  *NA
      set months-since-utility-assistance 13 ;its beeen over a year
      set months-since-rental-assistance 13 ;its beeen over a year
      set income-decreased-by-covid false
      set income-type item 17 hh-list-entry
      set annual-ss-income item 15 hh-list-entry
      set monthly-hh-ss-income annual-ss-income / 12
      set monthly-hh-income (annual-household-income / 12)

      set rental-arrears 0
      set utility-arrears 0

      ;setup the rental property
      ask patch-here [
        set tenant? true
        set is-a-rental-property? true
        set rental-puma item 0 hh-list-entry
        set number-of-rooms  item 6 hh-list-entry
        set rent  item 4 hh-list-entry
        set building-type item 2 hh-list-entry

      ]
    ]


  ]

end

to-report determine-SNAP [number-people]
  let funds  122 * number-people

;  if number-people = 1 [set funds 131]
;  if number-people = 2 [set funds 245]
;  if number-people = 3 [set funds 378]
;  if number-people = 4 [set funds 448]
;  if number-people = 5 [set funds 526]
;  if number-people = 6 [set funds 632]
;  if number-people = 7 [set funds 710]
;  if number-people = 8 [set funds 873]
;  if number-people > 8 [set funds 873] ;*NA
  report funds

end

to Setup-Cities

  ask patches with [pcolor = 45.7] [set township "Mesa"]
  ask patches with [pcolor = 15] [set township "Gilbert-Chandler"]
  ask patches with [pcolor = 55.3] [set township "Tempe"]
  ask patches with [pcolor = 114.2] [set township "Scottsdale"]
  ask patches with [pcolor = 105.7] [set township "Phoenix"]

end


to Go

    ; Community Assistance Programs Reset Their Monthly Funds
  set cap-maricopa-utility-pot (Annual-Maricopa-Utility-Pot / 12) * (population-representation-sample / 100) ; Total SFY 2020 Alerts
  set cap-mesa-utility-pot (Annual-Mesa-Utility-Pot / 12) * (population-representation-sample / 100) ; Total SFY 2020 Alerts
  set cap-phx-utility-pot (Annual-Phoenix-Utility-Pot / 12) * (population-representation-sample / 100) ; Total SFY 2020 Alerts
  set faith-based-assist-pot (Annual-Faith-Based-Charities / 12 ) * (population-representation-sample / 100);
  if month < 13[
    set cap-maricopa-rental-pot ( Annual-Maricopa-Rental-Pot / 12) * (population-representation-sample / 100) ;
    set cap-mesa-rental-pot ( Annual-Mesa-Rental-Pot / 12) * (population-representation-sample / 100);
    set cap-phx-rental-pot ( Annual-Phoenix-Rental-Pot / 12) * (population-representation-sample / 100);
  ]
  if month = 13[; ERA 1
    set cap-maricopa-rental-pot (15677653 ) * (population-representation-sample / 100) ;
    set cap-mesa-rental-pot ( 15760806) * (population-representation-sample / 100);
    set cap-phx-rental-pot ( 58823958 ) * (population-representation-sample / 100);
  ]
  if month = 15[ ; ERA 2
    set cap-maricopa-rental-pot cap-maricopa-rental-pot + ( 12404992 * (population-representation-sample / 100)) ;
    set cap-mesa-rental-pot cap-mesa-rental-pot + ( 12470788 * (population-representation-sample / 100));
    set cap-phx-rental-pot cap-phx-rental-pot + ( 61425795 * (population-representation-sample / 100));

  ]

    set cap-maricopa-rental-assist-monthly-apts Number-of-Assissted-Households-Per-Month * (population-representation-sample / 100);*MAG
    set cap-mesa-rental-assist-monthly-apts Number-of-Assissted-Households-Per-Month * (population-representation-sample / 100);*MAG
    set cap-phoenix-rental-assist-monthly-apts Number-of-Assissted-Households-Per-Month * (population-representation-sample / 100);*MAG

    ;Track Monthly Info
    set monthly-evicted-count 0
    set tracker-rental-assistance 0
    set tracker-utility-assistance 0
    set tracker-faith-based-assistance 0


    set hhs-requesting-appointments-rental 0
    set hhs-getting-appointments-rental 0
   set   hhs-requesting-appointments-utility 0
   set hhs-getting-appointments-utility 0

    ;MAG adjustment ERA 1 and 2 or month 13 and 16
    let msra-rule 12; months since rental assistance - this rule goes away in 1/2021
    if month > 12 [set msra-rule 0]


     ; Covid Income Shock Period
     ; Determine monthly Shock Frquency based on Pulse Survey, Expected Loss of Emplyment Income

    if month < 4 [set covid-shock-quantity 5]
    if month = 4 [set covid-shock-quantity 34]
    if month = 5 [set covid-shock-quantity 31]
    if month = 6 [set covid-shock-quantity 32]
    if month = 7 [set covid-shock-quantity 38]
    if month = 8 [set covid-shock-quantity 32]
    if month = 9 [set covid-shock-quantity 22]
    if month = 10 [set covid-shock-quantity 26]
    if month = 11 [set covid-shock-quantity 27]
    if month = 12 [set covid-shock-quantity 27]
    if month = 13 [set covid-shock-quantity 26]
    if month = 14 [set covid-shock-quantity 21]
    if month = 15 [set covid-shock-quantity 17]
    if month = 16 [set covid-shock-quantity 15]
    if month = 17 [set covid-shock-quantity 13]
    ;if month > 17 [set covid-shock-quantity 10]
  if month = 18 [set covid-shock-quantity 11]
  if month = 19 [set covid-shock-quantity 9]
  if month = 20 [set covid-shock-quantity 7]
  if month = 21 [set covid-shock-quantity 5]
  if month = 22 [set covid-shock-quantity 3]
  if month = 23 [set covid-shock-quantity 2]
  if month = 24 [set covid-shock-quantity 1]
  if month > 24 [set covid-shock-quantity 0]


    ask renters[


       let current-income monthly-hh-income

         ; No longer the same household getting impacts and dynamic based on the month
        ;Monthly Income Shock Occurs


    if (random 100 + 1) < covid-shock-quantity [
                set current-income current-income - ((covid-shock-magnitude / 100) * current-income)
    ]

       ; First Simulus Check
       if month = 5 and covid-effects [ ; NA need to update this so it is the number of adults not just people
            ifelse number-of-persons > 1
            [ if annual-household-income < 150000 [set current-income current-income + (first-stimulus-payment * 2)]]
            [ if annual-household-income < 75000 [set current-income current-income + first-stimulus-payment]]
       ]
       ; Second Simulus Check
       if month = 13 and covid-effects [ ; NA need to update this so it is the number of adults not just people
            ifelse number-of-persons > 1
            [ if annual-household-income < 150000 [set current-income current-income + (second-stimulus-payment * 2)]]
            [ if annual-household-income < 75000 [set current-income current-income + second-stimulus-payment]]
       ]

      ; Got rid of income-improvements - MAG


        set current-income current-income + monthly-hh-ss-income; social security and pap is not affected by income shocks  - general or covid
        set subsistence-cost monthly-subsistence-per-person * number-of-persons

        ; Add previous balance, adjusted income and PAP (determined by population file) and SNAP
        set balance (balance + current-income + PAP + SNAP) - subsistence-cost


;************************ CURRENTLY EVICTED *******************************************
       if evicted? = true
       [; Renters don't have a property and look for an available rental property
        ; evicted household finds new rentals or becomes evicted

        let my-old-rent monthly-rental-payment
        let available-rentals rental-properties with [tenant? = false and rent <= my-old-rent] ; Our assumption that people are looking for properties that do not have higher rent

        let my-current-balance balance
        let new-rental nobody
        ifelse first-last-month-rent-needed
        [set new-rental one-of available-rentals with [ rent * 2 < my-current-balance]] ; Must have 1st and last month's rent to get a new rental property
        [set new-rental one-of available-rentals]

        ;Move into the new rental property
        ifelse new-rental != nobody [

          move-to new-rental
          set evicted? false
          set months-evicted 0
          ask patch-here [set tenant? true]
          set monthly-rental-payment [rent] of patch-here
          set residence-type [building-type] of patch-here
          set previous-rental-location patch-here
          set town [township] of patch-here
          if residence-type = "house" [set shape "house"]
          if residence-type = "apartment" [set shape "apartment"]
          if residence-type = "trailer" [set shape "trailer"]
          ; rent is not paid now because it will be paid in the next section since they are now in a rental property
          ; except in the case that the 1st and last month are to be paid, then we take one of the months of rent here
          if first-last-month-rent-needed [set balance balance - [rent] of new-rental]

        ][;; Evicted agents that are unable to find a new place to live
          ; Pay Debts and save financial surplus
          set months-evicted months-evicted + 1
          set count-evicted count-evicted + 1

        ]

      ]

;************************ CURRENTLY IN A RENTAL PROPERTY *******************************************

      if evicted? = false
      [

        pay-rent
        pay-utilities


        ; ******* Rental Assistance *********
        if rental-arrears < 0  and months-since-rental-assistance > msra-rule[
           let assistance 0
           if month < 13 [set assistance determine-rental-assistance current-income rent ] ;MAG
           if month > 12 [set assistance determine-rental-assistance-ERA current-income rent ]
            if assistance > 0 [
               set months-since-rental-assistance 0
               set rental-arrears rental-arrears + assistance
               if rental-arrears > 0 [set rental-arrears 0 ]
               set balance balance + assistance ; balance was already decreased rent/utility when it was initially paid
            ]
        ]
        set months-since-rental-assistance months-since-rental-assistance + 1


        ; ******* Utility Assistance ********
        if utility-arrears < 0  and months-since-utility-assistance > msra-rule[
            let assistance determine-utility-assistance current-income utility-cost
            if assistance > 0 [
              set months-since-utility-assistance 0
              set utility-arrears utility-arrears + assistance
              if utility-arrears > 0 [set utility-arrears 0 ]
              set balance balance + assistance ; balance was already decreased rent/utility when it was initially paid
            ]
        ]
        set months-since-utility-assistance  months-since-utility-assistance  + 1


        ; ******* Faith Based Assistance ********

        if utility-arrears < 0 or rental-arrears < 0 [
          let f-assist determine-faith-based-assistance
          set balance balance + f-assist
        ]

        ifelse rental-arrears < 0 or utility-arrears < 0 [
          set unable-to-pay-utilities-or-rent unable-to-pay-utilities-or-rent + 1
          ;; for consecutive monthly cycles
          if unable-to-pay-utilities-or-rent > (consecutive-arrears-for-eviction - 1) [

           ;; renter evicted with probability
          if month < pause-month or month >= evictions-begin-again; COVID EVICTION PAUSE
          [ if random 100 < eviction-probability [

          ; *********************  Eviction  *********************

              set monthly-evicted-count monthly-evicted-count + 1
              set unable-to-pay-utilities-or-rent 0
              set rental-arrears 0;  0'd b/c the debt is captured in balance
              set utility-arrears 0; 0'd b/c the debt is captured in balance
              set evicted? true
              set months-evicted 0.5
              if [building-type] of patch-here = "house" [set count-evicted-from-home count-evicted-from-home + 1]
              if [building-type] of patch-here = "apartment" [set count-evicted-from-apt count-evicted-from-apt + 1]
              if [building-type] of patch-here = "trailer" [set count-evicted-from-trailer count-evicted-from-trailer + 1]
              ask patch-here [set tenant? false]
              set shape "person"
              move-to one-of empty-patches
        ]]
          ]
        ] [ ; NO Utility or Rental Arrears
            set unable-to-pay-utilities-or-rent 0

          ]

      ]; Renters finished Paying Bills and adjusting finances

  ]


    ;Display and Record Monthly Data
    set average-utility-arrears mean [utility-arrears] of renters
    set average-rental-arrears mean [rental-arrears] of renters
    if any? renters with [evicted? = false][set average-balance-renters mean [balance] of renters with [evicted? = false]]
    if any? renters with [evicted? = true][set average-balance-evicted mean [balance] of renters with [evicted? = true]]


    if month = 12 or month = 24 or month = 36 or month = 48 [
      set year year + 1 ; advance the calendar after 12 months
      if year > number-of-years [ stop ]
    ]

    set month month + 1
    set monthly-evicted-count-final monthly-evicted-count
    tick ; do this at the month instead of the year since this is the timescale we are interested in
    set count-evicted-from-home 0
    set count-evicted-from-apt 0
    set count-evicted-from-trailer 0
    set count-evicted 0

end

to pay-rent
  ifelse balance > 0 [
    set balance balance - monthly-rental-payment
    if balance < 0 [
         set rental-arrears rental-arrears + balance; rental-arrears is the amount the household was unable to pay, this allows for partial payment
        ]
  ] [ ; balance was negative
    set balance balance - monthly-rental-payment
    set rental-arrears rental-arrears +  (-1 * monthly-rental-payment); arrears are stored as negative numbers

  ]

end


to pay-utilities
  ifelse balance > 0 [
    set balance balance - utility-cost
    if balance < 0 [
         set utility-arrears balance + utility-arrears
        ]
  ] [ ; balance was negative
    set balance balance - utility-cost
    if balance < 0 [
         set utility-arrears (-1 * utility-cost) + utility-arrears ; arrears are stored as negative numbers
        ]
  ]


end

to-report determine-utility-assistance [income-this-month utility-bill]

  set hhs-requesting-appointments-utility hhs-requesting-appointments-utility + 1

  let utility-assistance-total 0

  ; Household income for the past 30 days is at or below 60% of the State Median Income.
  if income-this-month < item number-of-persons sixty-pct-state-median-income [
    ; Determine the amount of money that could be rewarded based on points in the LIHEAP Eligibility Worksheet
    let points 0
    ; LIHEAP Worksheet 1. Income Elgibility
    let pct-energy-burden 0
    ifelse income-this-month = 0 [set pct-energy-burden 100] [set pct-energy-burden (utility-bill / income-this-month) * 100] ; this negates a divide by 0 error
    ;;if pct-energy-burden < 5 gets no points
    if pct-energy-burden > 5  and pct-energy-burden < 11[ set points points + 3]
    if pct-energy-burden > 10  and pct-energy-burden < 16[ set points points + 4 ]
    if pct-energy-burden > 15  and pct-energy-burden < 21[set points points + 5 ]
    if pct-energy-burden > 20 [set points points + 6 ]
    ; LIHEAP Worksheet 2. Energy Need   *SB Characteristics that our synthetic pop doesn't have yet
    set points points +  random 5

    ; LIHEAP 3. / 4. Payment
    if points < 3 [ if utility-bill < 160 [ifelse utility-bill < 75 [set utility-assistance-total 75 ][set utility-assistance-total utility-bill]] ]
    if points > 2 and points < 7 [if utility-bill < 320 [ifelse utility-bill < 161 [set utility-assistance-total 161 ][set utility-assistance-total utility-bill]]]
    if points > 6 and points < 12 [if utility-bill < 480 [ifelse utility-bill < 321 [set utility-assistance-total 321 ][set utility-assistance-total utility-bill]]]
    if points > 11 and points < 15 [if utility-bill < 640 [ifelse utility-bill < 481 [set utility-assistance-total 481 ][set utility-assistance-total utility-bill]]]
    if points > 15 [if utility-bill < 800 [ifelse utility-bill < 641 [set utility-assistance-total 641 ][set utility-assistance-total utility-bill]]]

    ;Determine which CAP should be used

    if town = "Mesa" [
     ifelse cap-mesa-utility-pot > utility-assistance-total
      [set cap-mesa-utility-pot cap-mesa-utility-pot - utility-assistance-total   set hhs-getting-appointments-utility   hhs-getting-appointments-utility + 1]
      [set utility-assistance-total 0]
    ]
    if town = "Phoenix" [
      ifelse cap-phx-utility-pot > utility-assistance-total
      [set cap-phx-utility-pot cap-phx-utility-pot - utility-assistance-total set hhs-getting-appointments-utility   hhs-getting-appointments-utility + 1]
      [set utility-assistance-total 0]
    ]
    if town = "Gilbert-Chandler" or town = "Tempe" or town = "Scottsdale" [
      ifelse cap-maricopa-utility-pot > utility-assistance-total
      [set cap-maricopa-utility-pot cap-maricopa-utility-pot - utility-assistance-total set hhs-getting-appointments-utility   hhs-getting-appointments-utility + 1]
      [set utility-assistance-total 0]

    ]

  ]

  if utility-assistance-total > 0 [set tracker-utility-assistance tracker-utility-assistance + 1]
  report utility-assistance-total

end


to-report determine-rental-assistance [income-this-month rental-bill]

    let rental-assistance-total 0

    set hhs-requesting-appointments-rental hhs-requesting-appointments-rental + 1


    ;Determine which CAP should be used
    ; Household income for the past 30 days is at or below 60% of the State Median Income. *SB 150% fed pov level

    if town = "Mesa"  and cap-mesa-rental-assist-monthly-apts > 0  [ ;
      set cap-mesa-rental-assist-monthly-apts cap-mesa-rental-assist-monthly-apts - 1 ; use one of monthly appointments available
      set hhs-getting-appointments-rental hhs-getting-appointments-rental + 1
      if cap-mesa-rental-pot > rental-bill and rental-bill < 1200 and income-this-month < item number-of-persons sixty-pct-state-median-income
      [ set cap-mesa-rental-pot cap-mesa-rental-pot - rental-bill
        set rental-assistance-total rental-bill
      ]
    ]
    if town = "Phoenix" and cap-phoenix-rental-assist-monthly-apts > 0[
      set cap-phoenix-rental-assist-monthly-apts cap-phoenix-rental-assist-monthly-apts - 1 ; use one of monthly appointments available
      set hhs-getting-appointments-rental hhs-getting-appointments-rental + 1
      if cap-phx-rental-pot > rental-bill and rental-bill < 1200 and income-this-month < item number-of-persons sixty-pct-state-median-income
      [ set cap-phx-rental-pot cap-phx-rental-pot - rental-bill
        set rental-assistance-total rental-bill
      ]
    ]
    if town = "Gilbert-Chandler" or town = "Tempe" or town = "Scottsdale" and cap-maricopa-rental-assist-monthly-apts > 0 [
       set cap-maricopa-rental-assist-monthly-apts cap-maricopa-rental-assist-monthly-apts - 1 ; use one of monthly appointments available
       set hhs-getting-appointments-rental hhs-getting-appointments-rental + 1
      if cap-maricopa-rental-pot > rental-bill and rental-bill < 1200 and income-this-month < item number-of-persons sixty-pct-state-median-income
      [ set cap-maricopa-rental-pot cap-maricopa-rental-pot - rental-bill
        set rental-assistance-total rental-bill
      ]



    ]
  ;print rental-assistance-total
   if  rental-assistance-total > 0 [ set tracker-rental-assistance tracker-rental-assistance + 1]


  report rental-assistance-total


end


to-report determine-rental-assistance-ERA [income-this-month rental-bill]

  ; just need to calculate assistance nubmers - the rental arrears and balance will be updated
   let rental-assistance-total 0
   let utility-assistance-total 0
   let abs-rental-arrears abs rental-arrears
   let abs-utility-arrears abs utility-arrears

    set hhs-requesting-appointments-rental hhs-requesting-appointments-rental + 1

   ; Household income for the past 30 days is at or below 80% of the State Median Income. MAG
   if  income-this-month < item number-of-persons eighty-pct-state-median-income [
    let max-reward 15 * rental-bill ; ERA 1
    if month > 15 [set max-reward 18 * rental-bill ] ; ERA 2
    let max-u-reward 15 * utility-cost

    ; Do this once for rental and then repeat for utility
    ; There is a possbility of one hh taking more money than the cap has - leaving it alone for now though MAG
    if town = "Mesa"  and cap-mesa-rental-assist-monthly-apts > 0  [ ;
      if cap-mesa-rental-pot > rental-bill  and income-this-month < item number-of-persons eighty-pct-state-median-income
      [
        set cap-mesa-rental-assist-monthly-apts cap-mesa-rental-assist-monthly-apts - 1 ; use one of monthly appointments available
        set hhs-getting-appointments-rental hhs-getting-appointments-rental + 1
        ifelse abs-rental-arrears > max-reward [set rental-assistance-total max-reward][ set rental-assistance-total abs-rental-arrears]
        set cap-mesa-rental-pot cap-mesa-rental-pot - rental-assistance-total
        ifelse abs-utility-arrears > max-u-reward [set utility-assistance-total max-u-reward][ set utility-assistance-total abs-utility-arrears]
        set cap-mesa-rental-pot cap-mesa-rental-pot - utility-assistance-total
      ]
    ]
    if town = "Phoenix" and cap-phoenix-rental-assist-monthly-apts > 0[
      if cap-phx-rental-pot > rental-bill  and income-this-month < item number-of-persons eighty-pct-state-median-income
      [
       set cap-phoenix-rental-assist-monthly-apts cap-phoenix-rental-assist-monthly-apts - 1 ; use one of monthly appointments available
        set hhs-getting-appointments-rental hhs-getting-appointments-rental + 1
       ifelse abs-rental-arrears > max-reward [set rental-assistance-total max-reward][ set rental-assistance-total abs-rental-arrears]
       set cap-phx-rental-pot cap-phx-rental-pot - rental-assistance-total
       ifelse abs-utility-arrears > max-u-reward [set utility-assistance-total max-u-reward][ set utility-assistance-total abs-utility-arrears]
       set cap-phx-rental-pot cap-phx-rental-pot - utility-assistance-total
      ]
    ]
    if town = "Gilbert-Chandler" or town = "Tempe" or town = "Scottsdale" and cap-maricopa-rental-assist-monthly-apts > 0 [
      if cap-maricopa-rental-pot > rental-bill and income-this-month < item number-of-persons eighty-pct-state-median-income
      [
        set cap-maricopa-rental-assist-monthly-apts cap-maricopa-rental-assist-monthly-apts - 1 ; use one of monthly appointments available
        set hhs-getting-appointments-rental hhs-getting-appointments-rental + 1
        ifelse abs-rental-arrears > max-reward [set rental-assistance-total max-reward][ set rental-assistance-total abs-rental-arrears]
        set cap-maricopa-rental-pot cap-maricopa-rental-pot - rental-assistance-total
        ifelse abs-utility-arrears > max-u-reward [set utility-assistance-total max-u-reward][ set utility-assistance-total abs-utility-arrears]
        set cap-maricopa-rental-pot cap-maricopa-rental-pot - utility-assistance-total
      ]

    ]

   ]
  ;print rental-assistance-total
   if  rental-assistance-total > 0 [ set tracker-rental-assistance tracker-rental-assistance + 1]

  set utility-arrears utility-arrears + utility-assistance-total

  report rental-assistance-total + utility-assistance-total

end

to-report determine-faith-based-assistance

  let f-assistance 0
  ; the arrears are stored as negative numbers
  let ra abs rental-arrears
  let ua abs utility-arrears


  if faith-based-assist-pot > ra[
   set  faith-based-assist-pot faith-based-assist-pot - ra
   set  rental-arrears 0
   set f-assistance f-assistance + ra
   set tracker-faith-based-assistance tracker-faith-based-assistance + 1
  ]

  if faith-based-assist-pot > ua[
   set  faith-based-assist-pot faith-based-assist-pot - ua
   set  f-assistance f-assistance + ua
   set  utility-arrears 0
  ]

  report f-assistance

end


;Used to get the month value * the year. Reports 13 for the second January instead of 12 again. Created to deal with COVID specific deadlines
to-report report-month
  let this-month month

  if year > 1 [set this-month month - ((year - 1) * 12)]

   report this-month

end


; Used to translate between the actual name of the month and the numerical representation
to-report month-number [month-name]
  let month-number-is 0
  if month-name = "Jan" [set month-number-is 1]
  if month-name = "Feb" [set month-number-is 2]
  if month-name = "Mar" [set month-number-is 3]
  if month-name = "Apr" [set month-number-is 4]
  if month-name = "May" [set month-number-is 5]
  if month-name = "Jun" [set month-number-is 6]
  if month-name = "Jul" [set month-number-is 7]
  if month-name = "Aug" [set month-number-is 8]
  if month-name = "Sep" [set month-number-is 9]
  if month-name = "Oct" [set month-number-is 10]
  if month-name = "Nov" [set month-number-is 11]
  if month-name = "Dec" [set month-number-is 12]
  report month-number-is
end


;Unused Procedure designed to output global information.
to save-csv

  let filename "test"
    file-open (word filename ".csv")

  let text-out (sentence ","average-balance-renters","average-utility-arrears","average-rental-arrears","average-balance-evicted","tracker-rental-assistance","tracker-utility-assistance","tracker-faith-based-assistance","count renters with [evicted? = true]",")
  file-type text-out
   file-close

end

;Copyright: (C) 2021 by Sean Bergin and Joffa Applegate, School of Complex Adaptive Systems, Arizona State University
;License: This program is free software under the GPL-3.0 License. See https://choosealicense.com/licenses/gpl-3.0/ for license details.
@#$#@#$#@
GRAPHICS-WINDOW
326
10
1085
770
-1
-1
1.5
1
10
1
1
1
0
1
1
1
-250
250
-250
250
0
0
1
Months
30.0

BUTTON
8
10
142
43
Setup Simulation
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
154
10
290
43
Run Simulation
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
120
182
153
number-of-years
number-of-years
1
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
10
196
287
229
eviction-probability
eviction-probability
1
100
90.0
1
1
%
HORIZONTAL

PLOT
1100
11
1597
299
Evicted Households %
Month
NIL
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Phoenix" 1.0 0 -13345367 true "" "plot ((count renters with [evicted? = true and town = \"Phoenix\" and months-evicted = 0.5] ) / (count renters with [town = \"Phoenix\"])) * 100"
"Mesa" 1.0 0 -1184463 true "" "plot ((count renters with [evicted? = true and town = \"Mesa\" and months-evicted = 0.5]  ) / (count renters with [town = \"Mesa\"])) * 100"
"Scottsdale" 1.0 0 -10141563 true "" "plot ((count renters with [evicted? = true and town = \"Scottsdale\" and months-evicted = 0.5]  ) / (count renters with [town = \"Scottsdale\"])) * 100"
"Tempe" 1.0 0 -10899396 true "" "plot ((count renters with [evicted? = true and town = \"Tempe\" and months-evicted = 0.5]  ) / (count renters with [town = \"Tempe\"])) * 100"
"Gilbert-Chandler" 1.0 0 -2674135 true "" "plot ((count renters with [evicted? = true and town = \"Gilbert-Chandler\" and months-evicted = 0.5]  ) / (count renters with [town = \"Gilbert-Chandler\"])) * 100"
"Currently Evicted" 1.0 0 -7500403 true "" "plot ((count renters with [evicted? = true]) / (count renters)) * 100"

MONITOR
1100
305
1157
350
Year
year
17
1
11

MONITOR
1169
304
1226
349
Month
report-month
17
1
11

SLIDER
10
161
287
194
consecutive-arrears-for-eviction
consecutive-arrears-for-eviction
1
10
2.0
1
1
NIL
HORIZONTAL

PLOT
1102
357
1566
599
Funds & Arrears
Month
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Avg Balance Renters" 1.0 0 -14070903 true "" "plot average-balance-renters"
"Avg Balance Evicted" 1.0 0 -7500403 true "" "plot average-balance-evicted"

BUTTON
20
61
120
94
One Year
Go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
8
235
285
268
monthly-subsistence-per-person
monthly-subsistence-per-person
50
500
500.0
25
1
NIL
HORIZONTAL

SWITCH
9
277
285
310
first-last-month-rent-needed
first-last-month-rent-needed
0
1
-1000

INPUTBOX
204
814
360
874
Annual-Maricopa-Utility-Pot
3764676.0
1
0
Number

INPUTBOX
205
879
360
939
Annual-Mesa-Utility-Pot
1945593.0
1
0
Number

INPUTBOX
206
944
363
1004
Annual-Phoenix-Utility-Pot
6804035.0
1
0
Number

INPUTBOX
21
814
192
874
Annual-Maricopa-Rental-Pot
1.0E7
1
0
Number

INPUTBOX
21
879
194
939
Annual-Mesa-Rental-Pot
1.0E7
1
0
Number

INPUTBOX
22
945
195
1005
Annual-Phoenix-Rental-Pot
1.8E7
1
0
Number

INPUTBOX
370
813
535
873
Annual-Faith-Based-Charities
5000000.0
1
0
Number

SLIDER
374
888
523
921
population-representation-sample
population-representation-sample
1
100
10.0
1
1
NIL
HORIZONTAL

MONITOR
1236
304
1357
349
Monthly Evictions
monthly-evicted-count-final
0
1
11

PLOT
1102
608
1569
893
Financial Assistance
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Rental" 1.0 0 -14070903 true "" "plot tracker-rental-assistance"
"Utility" 1.0 0 -2674135 true "" "plot tracker-utility-assistance"
"Faith Based" 1.0 0 -14439633 true "" "plot tracker-faith-based-assistance"

TEXTBOX
17
332
247
366
Covid Eviction Parameters
14
0.0
1

CHOOSER
15
566
233
611
Evictions-Begin-Again-2021
Evictions-Begin-Again-2021
"Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"
7

SLIDER
16
522
228
555
covid-shock-magnitude
covid-shock-magnitude
0
100
80.0
1
1
%
HORIZONTAL

TEXTBOX
17
392
204
420
Covid Shocks Begin in April 2020
11
0.0
1

SWITCH
15
410
227
443
pause-evictions-April2020
pause-evictions-April2020
0
1
-1000

SLIDER
10
743
292
776
second-stimulus-payment
second-stimulus-payment
100
2000
600.0
100
1
$ per person
HORIZONTAL

SLIDER
11
704
292
737
first-stimulus-payment
first-stimulus-payment
100
2000
1200.0
100
1
$ per person
HORIZONTAL

SWITCH
17
353
156
386
covid-effects
covid-effects
0
1
-1000

TEXTBOX
19
487
169
515
Covid-Shock-Quantity Now Set With Pulse Survey Data
11
0.0
1

SLIDER
13
635
323
668
Number-of-Assissted-Households-Per-Month
Number-of-Assissted-Households-Per-Month
10
500
250.0
10
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

The purpose of this model is to explore the dynamics of residency and eviction for households renting in the greater Phoenix (Arizona) metropolitan area. The model uses a representative population of renters modified from American Community Survey (ACS) data that includes demographic, housing and economic information. Each month, households pay their subsistence, rental and utility bills. If a household is unable to pay their monthly rent or utility bill they apply for financial assistance. 

## HOW IT WORKS

The setup button loads a representational map of the Phoenix area and loads an agent population of households that are renters. 

The Go button begins a monthly simulation that begins in January of 2020 and continues a given number of years.


## CREDITS AND REFERENCES

Copyright: (C) 2021 by Sean Bergin and Joffa Applegate, Arizona State University
License: This program is free software under the GPL-3.0 License. See https://choosealicense.com/licenses/gpl-3.0/ for license details. 
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

apartment
false
0
Rectangle -7500403 true true 15 165 285 255
Rectangle -16777216 true false 120 195 180 255
Line -7500403 true 150 195 150 255
Rectangle -16777216 true false 30 180 105 240
Rectangle -16777216 true false 195 180 270 240
Line -16777216 false 0 165 300 165
Rectangle -7500403 true true 15 75 285 165
Rectangle -16777216 true false 30 105 105 165
Rectangle -16777216 true false 195 105 270 165
Rectangle -16777216 true false 120 105 180 165

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

building store
false
0
Rectangle -7500403 true true 30 45 45 240
Rectangle -16777216 false false 30 45 45 165
Rectangle -7500403 true true 15 165 285 255
Rectangle -16777216 true false 120 195 180 255
Line -7500403 true 150 195 150 255
Rectangle -16777216 true false 30 180 105 240
Rectangle -16777216 true false 195 180 270 240
Line -16777216 false 0 165 300 165
Polygon -7500403 true true 0 165 45 135 60 90 240 90 255 135 300 165
Rectangle -7500403 true true 0 0 75 45
Rectangle -16777216 false false 0 0 75 45

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

trailer
false
0
Rectangle -7500403 true true 15 165 285 240
Rectangle -16777216 true false 135 195 165 240
Rectangle -16777216 true false 45 195 90 225
Rectangle -16777216 true false 210 195 255 225
Line -16777216 false 0 165 300 165
Polygon -7500403 true true 0 165 45 150 75 150 225 150 255 150 300 165
Rectangle -7500403 true true 15 240 30 255
Rectangle -7500403 true true 105 240 120 255
Rectangle -7500403 true true 270 240 285 255
Rectangle -7500403 true true 180 240 195 255
Line -7500403 true 180 240 120 240

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment1-eviction-and-income-improvement-timing" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count renters with [evicted? = true]</metric>
    <metric>month</metric>
    <enumeratedValueSet variable="maximum-distance-for-new-apartment">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-shock-frequency">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eviction-probability">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="first-last-month-rent-needed">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="first-stimulus-payment">
      <value value="1200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-years">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-shock-magnitude">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Maricopa-Utility-Pot">
      <value value="3764676"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-shock-quantity">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-shock-magnitude">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-income-improvement-rate">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Phoenix-Rental-Pot">
      <value value="1800000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Evictions-Begin-Again-2021">
      <value value="&quot;Jan&quot;"/>
      <value value="&quot;Feb&quot;"/>
      <value value="&quot;Mar&quot;"/>
      <value value="&quot;Apr&quot;"/>
      <value value="&quot;May&quot;"/>
      <value value="&quot;Jun&quot;"/>
      <value value="&quot;Jul&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-improvement-begins">
      <value value="&quot;Jan&quot;"/>
      <value value="&quot;Feb&quot;"/>
      <value value="&quot;Mar&quot;"/>
      <value value="&quot;Apr&quot;"/>
      <value value="&quot;May&quot;"/>
      <value value="&quot;Jun&quot;"/>
      <value value="&quot;Jul&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consecutive-arrears-for-eviction">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Faith-Based-Charities">
      <value value="5000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-subsistence-per-person">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="second-stimulus-payment">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Mesa-Rental-Pot">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consider-distance-for-new-apartments">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Mesa-Utility-Pot">
      <value value="1945593"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Maricopa-Rental-Pot">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population-representation-sample">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pause-evictions-April2020">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-effects">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Phoenix-Utility-Pot">
      <value value="6804035"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-debt-reduction">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment2-income-shock" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count renters with [evicted? = true]</metric>
    <metric>month</metric>
    <enumeratedValueSet variable="maximum-distance-for-new-apartment">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-shock-frequency">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eviction-probability">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="first-last-month-rent-needed">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="first-stimulus-payment">
      <value value="1200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-years">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-shock-magnitude">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
      <value value="60"/>
      <value value="70"/>
      <value value="80"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Maricopa-Utility-Pot">
      <value value="3764676"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-shock-quantity">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-shock-magnitude">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-income-improvement-rate">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Phoenix-Rental-Pot">
      <value value="1800000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Evictions-Begin-Again-2021">
      <value value="&quot;Mar&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-improvement-begins">
      <value value="&quot;Mar&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consecutive-arrears-for-eviction">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Faith-Based-Charities">
      <value value="5000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-subsistence-per-person">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="second-stimulus-payment">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Mesa-Rental-Pot">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consider-distance-for-new-apartments">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Mesa-Utility-Pot">
      <value value="1945593"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Maricopa-Rental-Pot">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population-representation-sample">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pause-evictions-April2020">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-effects">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Phoenix-Utility-Pot">
      <value value="6804035"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-debt-reduction">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment3-second-stimulus-test" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count renters with [evicted? = true]</metric>
    <metric>month</metric>
    <enumeratedValueSet variable="maximum-distance-for-new-apartment">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-shock-frequency">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eviction-probability">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="first-last-month-rent-needed">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="first-stimulus-payment">
      <value value="1200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-years">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-shock-magnitude">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Maricopa-Utility-Pot">
      <value value="3764676"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-shock-quantity">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-shock-magnitude">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-income-improvement-rate">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Phoenix-Rental-Pot">
      <value value="1800000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Evictions-Begin-Again-2021">
      <value value="&quot;Mar&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-improvement-begins">
      <value value="&quot;Mar&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consecutive-arrears-for-eviction">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Faith-Based-Charities">
      <value value="5000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-subsistence-per-person">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="second-stimulus-payment">
      <value value="500"/>
      <value value="1000"/>
      <value value="1500"/>
      <value value="2000"/>
      <value value="2500"/>
      <value value="3000"/>
      <value value="3500"/>
      <value value="4000"/>
      <value value="4500"/>
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Mesa-Rental-Pot">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consider-distance-for-new-apartments">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Mesa-Utility-Pot">
      <value value="1945593"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Maricopa-Rental-Pot">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population-representation-sample">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pause-evictions-April2020">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-effects">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Phoenix-Utility-Pot">
      <value value="6804035"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-debt-reduction">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment4-covid-rental-debt-reduction" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count renters with [evicted? = true]</metric>
    <metric>month</metric>
    <enumeratedValueSet variable="maximum-distance-for-new-apartment">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eviction-probability">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="first-last-month-rent-needed">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-years">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-shock-magnitude">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Evictions-Begin-Again-2021">
      <value value="&quot;Mar&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-shock-quantity">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consecutive-arrears-for-eviction">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Phoenix-Rental-Pot">
      <value value="1800000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-improvement-begins">
      <value value="&quot;Mar&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Mesa-Rental-Pot">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consider-distance-for-new-apartments">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Mesa-Utility-Pot">
      <value value="1945593"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Maricopa-Rental-Pot">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population-representation-sample">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-effects">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-shock-frequency">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-rent-debt-reduction">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
      <value value="60"/>
      <value value="70"/>
      <value value="80"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="first-stimulus-payment">
      <value value="1200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Maricopa-Utility-Pot">
      <value value="3764676"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-shock-magnitude">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-income-improvement-rate">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="covid-debt-reduction">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Faith-Based-Charities">
      <value value="5000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-subsistence-per-person">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="second-stimulus-payment">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pause-evictions-April2020">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Annual-Phoenix-Utility-Pot">
      <value value="6804035"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
