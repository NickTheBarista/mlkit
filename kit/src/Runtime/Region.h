/*----------------------------------------------------------------*
 *                         Regions                                *
 *----------------------------------------------------------------*/
#ifndef REGION_H
#define REGION_H

#include "Flags.h"
 
/*
Overview
--------

This module defines the runtime representation of regions. 

There are two types of regions: {\em finite} and {\em infinite}.
A region is finite if its (finite) size has been found at compile
time and to which at most one object will ever be written. 
Otherwise it is infinite.

The runtime representation of a region depends on 
  (a) whether the region is finite or infinite;
  (b) whether profiling is turned on or not.

We describe each of the four possibilities in turn.

(a) Finite region of size n bytes (n%4==0) -- meaning that
    every object that may be stored in the region has size
    at most n bytes:
    (i)  without profiling, the region is n/4 words on the 
         runtime stack;
    (ii) with profiling, the region is represented by first
         pushing a region descriptor (see below) on the stack,
         then pushing an object descriptor (see below) on the stack and
         then reserving space for the object; the region descriptors
         of finite regions are linked together which the profiler
         can traverse.
(b) Infinite region -- meaning that the region can contain objects
    of different sizes. 
    (i)  without profiling, the region is represented by a
         {\em region descriptor} on the stack. The region descriptor
         points to the beginning and the end of a linked list of
         fixed size region pages (see below). 
    (ii) with profiling, the representation is the same as without
         profiling, except that the region descriptor contains more
         fields for profiling statistics.

A {\em region page} consists of a header and an array of words that
can be used for allocation.  The header takes up
HEADER_WORDS_IN_REGION_PAGE words, while the number of words
that can be allocated is ALLOCATABLE_WORDS_IN_REGION_PAGE.
Thus, a region page takes up
HEADER_WORDS_IN_REGION_PAGE + ALLOCATABLE_WORDS_IN_REGION_PAGE
words in all.

The Danish word 'klump' means 'chunk', in this case:  'region page'.
*/

// Uncomment the following line to enable region page statistics (for SMLserver)
//#define REGION_PAGE_STAT 1
#ifdef REGION_PAGE_STAT
typedef struct regionPageMapHashList {
  unsigned int n;                               /* reuse number */
  unsigned int addr;                            /* address of region page */
  struct regionPageMapHashList * next; /* next hashed element */
} RegionPageMapHashList;

typedef RegionPageMapHashList* RegionPageMap;

/* Size of region page map hash table in entries -- (2^n-1) */
#define REGION_PAGE_MAP_HASH_TABLE_SIZE 511
#define hashRegionPageIndex(addr) ((addr) % REGION_PAGE_MAP_HASH_TABLE_SIZE)
RegionPageMap* regionPageMapNew(void);
extern RegionPageMap* rpMap;
#endif /* REGION_PAGE_STAT */

#define ALLOCATABLE_WORDS_IN_REGION_PAGE 254

/* Number of words that can be allocated in each regionpage.  If you
 * change this, remember also to change
 * src/Compiler/Backend/X86/BackendInfo.sml. */

typedef struct klump {
  struct klump *n;                   /* NULL or pointer to next page. */
  struct ro *r;                      /* Pointer back to region descriptor. Used by GC. */
  int i[ALLOCATABLE_WORDS_IN_REGION_PAGE];  /* space for data*/
} Klump;

#define HEADER_WORDS_IN_REGION_PAGE 2 

/* Number of words in the header part of a region page. If you 
 * change this, remember also to change
 * src/Compiler/Backend/X86/BackendInfo.sml.
 *
 * ALLOCATABLE_WORDS_IN_REGION_PAGE + HEADER_WORDS_IN_REGION_PAGE must
 * be one 1Kb, used by GC.  */

#define is_rp_aligned(rp)  (((rp) & 0x3FF) == 0)

/* Free pages are kept in a free list. When the free list becomes
 * empty and more space is required, the runtime system calls the
 * operating system function malloc in order to get space for a number
 * (here 30) of fresh region pages: */

/* Size of allocated space in each SBRK-call. */
#define BYTES_ALLOC_BY_SBRK REGION_PAGE_BAG_SIZE*sizeof(Klump)  

/* When garbage collection is enabled, a single bit in a region page
 * descriptor specifies if the page is part of to-space during garbage
 * collection. At points between garbage collections, no region page
 * descriptor has the bit set; given a region page descriptor, the
 * to-space bit is the least significant bit in the next-pointer in
 * the region page descriptor. */

#ifdef ENABLE_GC
#define clear_tospace_bit(p)  (Klump*)((unsigned int)(p) & 0xFFFFFFFE)
#define set_tospace_bit(p)    (Klump*)((unsigned int)(p) | 0x1)
#define is_tospace_bit(p)     ((unsigned int)(p) & 0x1)
#else
#define clear_tospace_bit(p)  (p)
#endif

/* Region large objects idea: Modify the region based memory model so
 * that each ``infinite region'' (i.e., a region for which the size of
 * the region is not determined statically) contains a list of objects
 * allocated using the C library function `malloc'. When a region is
 * deallocated or reset, the list of malloced objects in the region
 * are freed using the C library function `free'. The major reason for
 * large object support is to gain better indexing properties for
 * arrays and vectors. Without support for large objects, arrays and
 * vectors must be split up in chunks. With strings implemented as
 * linked list of pages, indexing in large character arrays takes time
 * which is linear in the index parameter and with word-vectors and
 * word-arrays being implemented as a tree structure, indexing in
 * word-vectors and word-arrays take time which is logarithmic in the
 * index parameter.  -- mael 2001-09-13 */

/* For tag-free garbage collection of pairs, we make sure that large
 * objects are aligned on 1K boundaries, which makes it possible to
 * determine if a pointer points into the stack, constants in data
 * space, a region in from-space, or a region in to-space. The orig
 * pointer points back to the memory allocated by malloc (which holds
 * the large object). */

typedef struct lobjs {
  struct lobjs* next;     // pointer to next large object or NULL
#ifdef ENABLE_GC
  char* orig;             // pointer to memory allocated by malloc - for freeing
#endif
  unsigned int value;     // a large object; inlined to avoid pointer-indirection
} Lobjs;

/* When garbage collection is enabled, a bit in a large object
 * descriptor specifies that the object is indeed a large object. The
 * bit helps the garbage collector determine, given a pointer p to an
 * object, whether p points to a tag-free pair. */

#ifdef ENABLE_GC
#define clear_lobj_bit(p)     (Lobjs*)((unsigned int)(p) & 0xFFFFFFFD)
#define set_lobj_bit(p)       (Lobjs*)((unsigned int)(p) | 0x2)
#define is_lobj_bit(p)        ((unsigned int)(p) & 0x2)
#else
#define clear_lobj_bit(p)     (p)
#define set_lobj_bit(p)       (p)
#endif /* ENABLE_GC */

/* 
Region descriptors
------------------
ro is the type of region descriptors. Region descriptors are kept on
the stack and are linked together so that one can traverse the stack
of regions (for profiling and for popping of regions when exceptions
are raised) 
*/

typedef struct ro {
  struct ro * p;       /* Pointer to previous region descriptor. It has to be at 
                          the bottom of the structure */
  int * a;             /* Pointer to first unused word in the newest region page
                          of the region. */
  int * b;             /* Pointer to the border of the newest region page, defined as the address
                          of the first word to follow the region page. One maintains
                          the invariant a<=b;  a=b means the region page is full.*/
  Klump *fp;           /* Pointer to the oldest (first allocated) page of the region. 
                          The beginning of the newest page of the region can be calculated
                          as a fixed offset from b. Thus the region descriptor gives
                          direct access to both the first and the last region page
                          of the region. This makes it possible to de-allocate the
                          entire region in constant time, by appending it to the free list.*/

  /* here are the extra fields that are used when profiling is turned on: */
  #ifdef PROFILING
  unsigned int allocNow;     /* Number of words allocated in region (excl. profiling data). */
  unsigned int allocProfNow; /* Number of words allocated in region for profiling data. */
  unsigned int regionId;     /* Id on region. */
  #endif

  Lobjs *lobjs;     // large objects: a list of malloced memory in each region
} Ro;

typedef Ro* Region;

#define sizeRo (sizeof(Ro)/4) /* size of region descriptor in words */
#define sizeRoProf (3)        /* We use three words extra when profiling. */

#define freeInRegion(rAddr)   (rAddr->b - rAddr->a) /* Returns freespace in words. */

#define descRo_a(rAddr,w) (rAddr->a = rAddr->a - w) /* Used in IO.inputStream */


/* When garbage collection is enabled, a bit in the region descriptor
 * is used to determine if a region holds pairs only, which makes it
 * possible to use a tag-free scheme for pairs.  */

#ifdef ENABLE_GC
#define is_pairregion(rd)           ((unsigned int)((rd)->fp) & 0x01)
#define set_pairregion(rd)          (rd->fp = (Klump*)(((unsigned int)((rd)->fp)) | 0x01))
#define clear_pairregion(fp)        ((Klump*)((unsigned int)(fp) & 0xFFFFFFFE))
#else
#define clear_pairregion(fp)        (fp)
#endif /*ENABLE_GC*/

/*
Region polymorphism
-------------------
Regions can be passed to functions at runtime. The machine value that represents
a region in this situation is a 32 bit word. The least significant bit is 1
iff the region is infinite. The second least significant bit is 1 iff stores
into the region should be preceded by emptying the region of values before
storing the new value (this is called storing a value at the {\em bottom}
of the region and is useful for, among other things, tail recursion).

*/

/* Operations on the two least significant   */
/* bits in a regionpointer.                  */
/* C ~ 1100, D ~ 1101, E ~ 1110 og F ~ 1111. */
#define setInfiniteBit(x)   ((x) | 0x00000001)
#define clearInfiniteBit(x) ((x) & 0xFFFFFFFE)
#define setAtbotBit(x)      ((x) | 0x00000002)
#define clearAtbotBit(x)    ((x) & 0xFFFFFFFD)
#define setStatusBits(x)    ((x) | 0x00000003)
#define clearStatusBits(x)  ((Region)(((unsigned int)(x)) & 0xFFFFFFFC))
#define is_inf_and_atbot(x) ((((unsigned int)(x)) & 0x00000003)==0x00000003)
#define is_inf(x)           ((((unsigned int)(x)) & 0x00000001)==0x00000001)
#define is_atbot(x)         ((((unsigned int)(x)) & 0x00000002)==0x00000002)

/*----------------------------------------------------------------*
 * Type of freelist and top-level region                          *
 *                                                                *
 * When the KAM backend is used, we use an indirection to hold    *
 * the top-level region, so as to support multiple threads.       *
 *----------------------------------------------------------------*/

extern Klump * freelist;

#ifdef KAM
#define TOP_REGION   (*topRegionCell)
void free_region_pages(Klump* first, Klump* last);
#else
extern Ro * topRegion;
#define TOP_REGION   topRegion
#endif


/*----------------------------------------------------------------*
 *        Prototypes for external and internal functions.         *
 *----------------------------------------------------------------*/
#ifdef KAM
Region allocateRegion(Region roAddr, Region* topRegionCell);
void deallocateRegion(Region* topRegionCell);
void deallocateRegionsUntil(Region rAdr, Region* topRegionCell);
#else
Region allocateRegion(Region roAddr);
void deallocateRegion();
void deallocateRegionsUntil(Region rAddr);
void deallocateRegionsUntil_X86(Region rAddr);
#endif

int *alloc (Region rAddr, int n);
void callSbrk();

#ifdef ENABLE_GC_OLD
void callSbrkArg(int no_of_region_pages);
#endif

#ifdef ENABLE_GC
Region allocatePairRegion(Region roAddr);
#ifdef PROFILING
Region allocPairRegionInfiniteProfiling(Region r, unsigned int regionId);
Region allocPairRegionInfiniteProfilingMaybeUnTag(Region r, unsigned int regionId);
#endif /* PROFILING */
#endif /* ENABLE_GC */

Region resetRegion(Region rAddr);

/*----------------------------------------------------------------*
 *        Declarations to support profiling                       *
 *----------------------------------------------------------------*/
#define notPP 0 /* Also used by GC */
#ifdef PROFILING

/* 
Here is the type of region descriptors for finite regions when
profiling is enabled (see item (a)(ii) at the beginning of the file):
*/

typedef struct finiteRegionDesc {
  struct finiteRegionDesc * p;  /* Has to be in the bottom of the descriptor 
                                   for deallocation. */
  int regionId;                 /* If msb. set then infinite region. (? - mads)*/
} FiniteRegionDesc;
#define sizeFiniteRegionDesc (sizeof(FiniteRegionDesc)/4)

/* 
Object descriptors
------------------
When profiling is turned on, every object is prefixed by an
object descriptor, containing the information that is needed
in order to traverse objects in regions and identify allocation
points in the source program. A {\em program point} is an integer
which identifies the point in the source program where a value
is created - the user turns on a flag in the compiler to make
it print programs annotated with their program points.

Every object is stored taking up a multiple of words (not bytes).
This applies irrespective of whether profiling is turned on or not.
*/

typedef struct objectDesc {
  int atId;               /* Allocation point. */
  int size;               /* Size of object in bytes. */
} ObjectDesc;
#define sizeObjectDesc (sizeof(ObjectDesc)/4)

/* 
Profiling is done by scanning the store at regular intervals.
Every such interruption of the normal execution is called
a {\em profile tick}. During a profile tick, the runtime system
scans all the regions accessible from the region stack (which
is one of the reasons why region descriptors are linked together).
The scanning of an infinite region is done by scanning each page
in turn. Scanning of a page starts at the left end and progresses
from object to object (using the size information that prefixes
every object) and it stops when the value 'notPP' follows after
an object:
*/

/*----------------------------------------------------------------------*
 * Extern declarations, mostly of global variables that store profiling *
 * information. See Hallenberg's report for details.
 * ---------------------------------------------------------------------*/
extern unsigned int callsOfDeallocateRegionInf,
                    callsOfDeallocateRegionFin,
                    callsOfAlloc,
                    callsOfResetRegion,
                    callsOfDeallocateRegionsUntil,
                    callsOfAllocateRegionInf,
                    callsOfAllocateRegionFin,
                    callsOfSbrk,
                    maxNoOfPages,
                    noOfPages,
                    allocNowInf,
                    maxAllocInf,
                    allocNowFin,
                    maxAllocFin,
                    allocProfNowInf,
                    maxAllocProfInf,
                    allocProfNowFin,
                    maxAllocProfFin,
                    maxAlloc,
                    regionDescUseInf,
                    maxRegionDescUseInf,
                    regionDescUseProfInf,
                    maxRegionDescUseProfInf,
                    regionDescUseProfFin,
                    maxRegionDescUseProfFin,
                    maxProfStack,
                    allocatedLobjs;

extern FiniteRegionDesc * topFiniteRegion;
extern int size_to_space;

/* Profiling functions. */
Region allocRegionInfiniteProfiling(Region roAddr, unsigned int regionId);
Region allocRegionInfiniteProfilingMaybeUnTag(Region roAddr, unsigned int regionId);
void allocRegionFiniteProfiling(FiniteRegionDesc *rdAddr, unsigned int regionId, int size);
void allocRegionFiniteProfilingMaybeUnTag(FiniteRegionDesc *rdAddr, unsigned int regionId, int size);
int *deallocRegionFiniteProfiling(void);
int *allocProfiling(Region rAddr,int n, int pPoint);  // used by Table.c
#endif /*Profiling*/

void printTopRegInfo();
int size_free_list();

void free_lobjs(Lobjs* lobjs);

#endif /*REGION_H*/