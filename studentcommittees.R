library(xtable)

d = read.csv("studentcommittees.csv")
d$School = factor(d$School, levels=c("ISU","UCSB"))
d$Chair  = factor(d$Chair, levels=c("Chair","Co-chair",""))

d_levels = levels(d$Department)
d$Department = factor(d$Department, levels=c("STAT",d_levels[-which(d_levels=="STAT")]))

d = d[order(d$School, d$Degree, d$Completed, d$Chair, d$Department),]

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


tab = xtable(d, 
      caption="Graduate student committees",
      label="tab:studentcommittees")
print(tab, file="studentcommittees.tex", 
      include.rownames=FALSE,
      table.placement="h")


# ISU non-STAT committees
#d[d$School=="ISU" & d$Department != "STAT",]


q("no")

