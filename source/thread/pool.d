module hurrican.thread.pool;

/**
 * @license http://forum.dlang.org/thread/gvqbqg$1dv1$1@digitalmars.com
 */

import core.sys.posix.pthread;  // just for pthread_self()
import core.thread;
import core.sync.mutex;
import core.sync.condition;
import std.c.time;
import std.stdio;

private struct Job
{
    Job *next;
    void function() fn;
    void delegate() dg;
    void *arg;
    int   call;
}

/**
* semi-daemon thread of thread pool
*/
class CThreadPool
{
public:
    /**
    * Constructs a CThreadPool
    * @param nMaxThread {int} the max number threads in thread pool
    * @param idleTimeout {int} when > 0, the idle thread will
    *  exit after idleTimeout seconds, if == 0, the idle thread
    *  will not exit
    * @param sz {size_t} when > 0, the thread will be created which
    *  stack size is sz.
    */
    this(int nMaxThread, int idleTimeout, size_t sz = 0)
    {
        m_nMaxThread = nMaxThread;
        m_idleTimeout = idleTimeout;
        m_stackSize = sz;
        m_mutex = new Mutex;
        m_cond = new Condition(m_mutex);
    }

    /**
    * Append one task into the thread pool's task queue
    * @param fn {void function()}
    */
    void append(void function() fn)
    {
        Job *job;
        char  buf[256];

        if (fn == null) {
            throw new Exception("fn null");
        }

        job = new Job;
        job.fn = fn;
        job.next = null;
        job.call = Call.FN;

        m_mutex.lock();
        append(job);
        m_mutex.unlock();
    }

    /**
    * Append one task into the thread pool's task queue
    * @param dg {void delegate()}
    */
    void append(void delegate() dg)
    {
        Job *job;
        char  buf[256];

        if (dg == null) {
            throw new Exception("dg null");
        }

        job = new Job;
        job.dg = dg;
        job.next = null;
        job.call = Call.DG;

        m_mutex.lock();
        append(job);
        m_mutex.unlock();
    }

    /**
    * If dg not null, when one new thread is created, dg will be called.
    * @param dg {void delegate()}
    */
    void onThreadInit(void delegate() dg)
    {
        m_onThreadInit = dg;
    }

    /**
    * If dg not null, before one thread exits, db will be called.
    * @param dg {void delegate()}
    */
    void onThreadExit(void delegate() dg)
    {
        m_onThreadExit = dg;
    }

private:
    enum Call { NO, FN, DG }

    Mutex m_mutex;
    Condition m_cond;
    size_t m_stackSize = 0;

    Job* m_jobHead = null, m_jobTail = null;
    int m_nJob = 0;
    bool m_isQuit = false;
    int m_nThread = 0;
    int m_nMaxThread;
    int m_nIdleThread = 0;
    int m_overloadTimeWait = 0;
    int m_idleTimeout;
    time_t m_lastWarn;

    void delegate() m_onThreadInit;
    void delegate() m_onThreadExit;
    void append(Job *job)
    {
        if (m_jobHead == null) {
            m_jobHead = job;
        }       
        else {
            m_jobTail.next = job;
        }

        m_jobTail = job;
        m_nJob++;

        if (m_nIdleThread > 0) {
            m_cond.notify();
        } else if (m_nThread < m_nMaxThread) {
            Thread thread = new Thread(&doJob);
            thread.isDaemon = true;
            thread.start();
            m_nThread++;
        } else if (m_nJob > 10 * m_nMaxThread) {
            time_t now = time(null);
            if (now - m_lastWarn >= 2) {
                m_lastWarn = now;
            }
            if (m_overloadTimeWait > 0) {
                Thread.sleep(dur!("msecs")( m_overloadTimeWait ));
            }
        }
    }
    void doJob()
    {
        Job *job;
        int status;
        bool timedout;
        long period = m_idleTimeout * 10_000_000;

        if (m_onThreadInit != null) {
            m_onThreadInit();
        }

        m_mutex.lock();
        for (;;) {
            timedout = false;

            while (m_jobHead == null && !m_isQuit) {
                m_nIdleThread++;
                if (period > 0) {
                    try {
                        if (m_cond.wait(dur!("msecs")( period )) == false) {
                            timedout = true;
                            break;
                        }
                    } catch (SyncException e) {
                        m_nIdleThread--;
                        m_nThread--;
                        m_mutex.unlock();
                        
                        if (m_onThreadExit != null) {
                            m_onThreadExit();
                        }

                        throw e;
                    }
                } else {
                    m_cond.wait();
                }
                m_nIdleThread--;
            }  /* end while */
            job = m_jobHead;

            if (job != null) {
                m_jobHead = job.next;
                m_nJob--;
                if (m_jobTail == job) {
                    m_jobTail = null;
                }
                /* the lock shuld be unlocked before enter
                working processs */
                m_mutex.unlock();
                switch (job.call) {
                    case Call.FN:
                        job.fn();
                        break;
                    case Call.DG:
                        job.dg();
                        break;
                    default:
                        break;
                }
                /* lock again */
                m_mutex.lock();
            }
            if (m_jobHead == null && m_isQuit) {
                m_nThread--;
                if (m_nThread == 0) {
                    m_cond.notifyAll();
                }

                break;
            }
            if (m_jobHead == null && timedout) {
               m_nThread--;
               break;
            }
        }

        m_mutex.unlock();

        writefln("Thread(%d) of ThreadPool exit now", pthread_self());
        if (m_onThreadExit != null) {
            m_onThreadExit();
        }
    }
}