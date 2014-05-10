*! version 0.14.4  17apr2014
*! author: George G. Vega Yon

/**oxygen
 * @brief Waits until every process finishes or stops the processes
 * @param parallelid Parallel instance id.
 * @param nclusters Number of clusters.
 * @param timeout Time (in secs) before abort.
 * @returns Number of clusters that stopped with error.
 */
mata:
real scalar parallel_finito(
	string scalar parallelid,
	| real scalar nclusters,
	real scalar timeout
	)
	{
	
	display(sprintf("{it:Waiting for the clusters to finish...}"))
	
	// Setting default parameters
	if (nclusters == J(1,1,.)) nclusters = strtoreal(st_global("PLL_CLUSTERS"))
	if (timeout == J(1,1,.)) timeout = 6000
	
	// Variable definitios
	real scalar in_fh, out_fh, time
	real scalar suberrors, i, errornum
	string scalar fname
	string scalar msg
	real scalar bk, pressed
	real rowvector pendingcl
	
	// Initial number of errors
	suberrors = 0
	
	/* Temporaly sets break key off */
	/* In windows (by now) parallel cannot use the breakkey */
	bk=querybreakintr();
	if (c("os")!="Windows") 
	{
		bk = setbreakintr(0)
		pressed=0
	}
	
	/* Checking conextion timeout */
	pendingcl = J(1,0,.)
	for(i=1;i<=nclusters;i++)
	{		
		/* Building filename */
		fname = sprintf("__pll%s_do%04.0f.log", parallelid, i)
		time = 0
		while (!fileexists(fname) & ((++time)*100 < timeout) & !breakkey())
			stata("sleep 100")
			
		if (!fileexists(fname))
		{
			display(sprintf("{it:cluster %04.0f} {error:has finished with a connection error -601- (timeout) ({stata search r(601):see more})...}", i))
			suberrors++
			continue
		}
		else pendingcl = pendingcl, i
			
		timeout = timeout - time*100
	}
	
	/* If there are as many errors as clusters, then exit */
	if (suberrors == nclusters) return(suberrors)
	
	string scalar logfilename

	while(length(pendingcl)>0)
	{
		
		// Building filename
		for (i=1;i<=nclusters;i++)
		{
			/* If this cluster is ready, then continue */
			if (!any(pendingcl :== i)) continue
			
			fname = sprintf("__pll%s_finito%04.0f", parallelid, i)
			
			if (breakkey() & !pressed) 
			{ /* If the user pressed -break-, each instance will try to finish the work through parallel finito */
				/* Message */
				display(sprintf("{it:The user pressed -break-. Trying to stop the clusters...}"))
			
				/* Openning and checking for the new file */
				fname = sprintf("__pll%s_break", parallelid)
				if (fileexists(fname)) _unlink(fname)
				out_fh = fopen(fname, "w", 1)
				
				/* Writing and exit */
				fput(out_fh, "1")
				fclose(out_fh)
				
				pressed = 1
				fname = sprintf("__pll%s_finito%04.0f", parallelid, i)
				
			}
		
			if (fileexists(fname)) // If the file exists
			{
				/* Opening the file and looking for somethign different of 0
				(which is clear) */
				in_fh = fopen(fname, "r", 1)
				if ((errornum=strtoreal(fget(in_fh))))
				{
					
					/* Copying log file */
					logfilename = sprintf("%s__pll%s_do%04.0f.log", (c("os") == "Windows" ? "" : "/"), parallelid, i)
					stata(sprintf(`"cap copy __pll%s_do%04.0f.log "\`c(tmpdir)'%s", replace"', parallelid, i, logfilename))

					msg = fget(in_fh)
					if (msg == J(0,0,"")) display(sprintf(`"{it:cluster %04.0f} {error:has finished with an error -%g- ({stata view "\`c("tmpdir")'%s":view log})...}"', i, errornum, logfilename))
					else display(sprintf(`"{it:cluster %04.0f} {error:has finished with an error -%g- %s ({stata view "\`c(tmpdir)'%s":view log})...}"', i, errornum, msg, logfilename))
					suberrors++
				}
				else display(sprintf("{it:cluster %04.0f} {text:has finished without any error...}", i))
				fclose(in_fh)
				
				/* Taking the finished cluster out of the list */
				pendingcl = select(pendingcl, pendingcl :!= i)
				
				continue
			} /* Else just wait for it 1/10 of a second! */
			else stata("sleep 100")
		}
	}
	
	/* Returing to old break value */
	if (querybreakintr()!=bk) 
	{
		breakkeyreset()
		(void) setbreakintr(bk)
	}

	if (suberrors) display(sprintf("{hline 80}{break}{text:{it:Enter -parallel seelog #- to checkout logfiles of clusters with errors.}}{break}{hline 80}"))
	
	return(suberrors)
	
}
end

