library(xtable)

d = read.csv("studentcommittees.csv")

d = d[order(d$Completed, d$Degree, d$Department, decreasing=TRUE),]

tab = xtable(d[d$School=="ISU", ])
print(tab, file="ISUstudentcommittees.tex", include.rownames=FALSE)


tab = xtable(d[d$School=="UCSB", ])
print(tab, file="UCSBstudentcommittees.tex", include.rownames=FALSE)


# ISU non-STAT committees
d[d$School=="ISU" & d$Department != "STAT",]