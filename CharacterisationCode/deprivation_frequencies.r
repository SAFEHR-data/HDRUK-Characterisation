#deprivation_frequencies.r
#andy south 2025-03-20


imd <- cdm$observation |> 
  filter(observation_concept_id==35812882) |> 
  collect()

freq_imd <- imd |> count(value_as_number)

#aggregating decile to quintile
freq_imd2 <- freq_imd |> 
  mutate(quintile=trunc((1+value_as_number)/2))

freq_quintile <- freq_imd2 |> 
  group_by(quintile) |> 
  summarise(quintile_count=sum(n))

