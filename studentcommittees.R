library(xtable)

d = read.csv("studentcommittees.csv")

d = d[order(d$School, d$Completed, d$Degree, d$Department, decreasing=TRUE),]

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