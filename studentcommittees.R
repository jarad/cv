library(plyr)
library(dplyr)
library(xtable)

d = read.csv("studentcommittees.csv") %>%
  mutate(School = factor(School, levels=c("ISU","UCSB")),
         Chair  = factor(Chair, levels=c("Chair","Co-chair","")))

d_levels = levels(d$Department)
d$Department = factor(d$Department, levels=c("STAT",d_levels[-which(d_levels=="STAT")]))

#d = d[order(d$School, d$Degree, d$Completed, d$Chair, d$Department),]

d = d %>% arrange(School, desc(Completed), Degree, Chair, Department)

#tab = xtable(d[d$School=="ISU", ], 
#      caption="Graduate student committees at ISU",
#      label="isustudentcommittees")
#print(tab, file="ISUstudentcommittees.tex",
#      include.rownames=FALSE,
#      table.placement="h")


#tab = xtable(d[d$School=="UCSB", ], 
#      caption="Graduate student committees at UCSB",
#      label="ucsbstudentcommittees")
#print(tab, file="UCSBstudentcommittees.tex",
#      include.rownames=FALSE,
#      table.placement="h")


# tab = xtable(d, 
#       caption="Graduate student committees",
#       label="tab:studentcommittees")
# print(tab, file="studentcommittees.tex", 
#       include.rownames=FALSE,
#       table.placement="h")

# Chair or co-chair
tab = xtable(d %>% 
               filter(Chair %in% c('Chair','Co-chair')) %>%
               arrange(School, desc(Completed), Degree, Chair), 
      caption="Students Advised",
      label="tab:advisees")
print(tab, file="advisees.tex", 
      include.rownames=FALSE,
      table.placement="h",
      caption.placement="top")

# Number of committees I am on including Chair and Co-chair
d = d %>%
  mutate(STAT = ifelse(d$Department %in% c('STAT','PSTAT'), 'Yes', 'No'),
         In_progress = ifelse(d$Completed == 'In progress', 'Yes', 'No'))

s = ddply(d, 
          .(In_progress,Degree,STAT), 
          summarize,
          n = length(Student))


tab = xtable(s %>%
               select(In_progress, Degree, STAT, n) %>%
               arrange(STAT, Degree, In_progress), 
             caption='Student Committees',
             label="tab:committees")
print(tab, file="committees.tex", 
      include.rownames=FALSE,
      table.placement="h",
      caption.placement="top")


# ISU non-STAT committees
#d[d$School=="ISU" & d$Department != "STAT",]

